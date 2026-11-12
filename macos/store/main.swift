// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// The Mac App Store build's store helper: buying Pro with StoreKit 2. A
// fused Lota app can't call StoreKit, which is Swift's alone, so the game
// starts this small program, shipped in the app at
// Contents/Helpers/dot-popper-store, once for each request
// (Shell::StoreHelper). It takes the same dotpopper-store: URL the iOS
// host catches (ios/host/Host/Store.swift), with file=- to mean its
// standard output, does that one request, and writes each answer there,
// the whole state each time, followed by an empty line:
//
//   answer=7              the number of the request this answers
//   owned=1               whether this player has the product
//   state=ready           loading, working, ready, pending, cancelled,
//                         restored, none, failed or unavailable
//   price=$1.99           the store's own, in the player's currency
//   receipt=apple:<JWS>   while owned, the transaction as StoreKit signed
//                         it, which the game verifies itself against
//                         Apple's root (Receipt::Apple)
//
// "owned" alone grants nothing: the game takes Pro only from the receipt.
// Owned purchases come from Transaction.currentEntitlements, which StoreKit
// answers from the Mac's cache, so a launch with no internet still finds
// Pro. Then it exits. A purchase approved later (Ask to Buy) is found by
// the next launch's open.
//
//   dot-popper-store 'dotpopper-store://open?n=1&product=com.setdef.dotpopper.pro&file=-'
//   dot-popper-store --check     says it runs, and asks StoreKit nothing
import AppKit
import Foundation
import StoreKit

/// The longest any request may take, a purchase included, before the
/// helper gives up and exits, so none outlives the game for long.
let longest: TimeInterval = 15 * 60

struct Request {
  let action: String
  let product: String
  let number: Int

  init?(_ text: String) {
    guard let url = URL(string: text), url.scheme?.lowercased() == "dotpopper-store",
      let action = url.host,
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let product = items.first(where: { $0.name == "product" })?.value,
      items.first(where: { $0.name == "file" })?.value == "-",
      let number = items.first(where: { $0.name == "n" })?.value.flatMap({ Int($0) })
    else { return nil }
    self.action = action
    self.product = product
    self.number = number
  }
}

@MainActor
final class Keeper {
  private let request: Request
  private var owned = false
  private var receipt = ""
  private var state = "loading"
  private var price = ""

  init(_ request: Request) { self.request = request }

  func perform() async {
    switch request.action {
    case "open": await open()
    case "buy": await buy()
    case "restore": await restore()
    default:
      state = "failed"
      write()
    }
  }

  private func open() async {
    state = "loading"
    write()
    await refreshOwned()
    write()
    state = await product() == nil ? "unavailable" : "ready"
    write()
  }

  private func buy() async {
    state = "working"
    write()
    await refreshOwned()
    guard let product = await product() else {
      state = "failed"
      write()
      return
    }
    // The purchase sheet is the system's; an accessory app may show it in
    // front of the game.
    NSApplication.shared.activate(ignoringOtherApps: true)
    do {
      switch try await product.purchase() {
      case .success(let result):
        switch result {
        case .verified(let transaction):
          await transaction.finish()
          receipt = result.jwsRepresentation
          owned = true
          state = "ready"
        case .unverified(_, let error):
          FileHandle.standardError.write(Data("StoreKit could not verify the purchase: \(error)\n".utf8))
          state = "failed"
        }
      case .pending:
        state = "pending"
      case .userCancelled:
        state = "cancelled"
      @unknown default:
        state = "failed"
      }
    } catch {
      FileHandle.standardError.write(Data("the purchase failed: \(error)\n".utf8))
      state = cancelled(error) ? "cancelled" : "failed"
    }
    write()
  }

  /// Restore Purchases. AppStore.sync can ask the player to sign in, so it
  /// runs only when the player asks; open sees past purchases without it.
  private func restore() async {
    state = "working"
    write()
    do {
      try await AppStore.sync()
      await refreshOwned()
      state = owned ? "restored" : "none"
    } catch {
      state = cancelled(error) ? "cancelled" : "failed"
    }
    write()
  }

  private func product() async -> Product? {
    guard let found = try? await Product.products(for: [request.product]).first else { return nil }
    price = found.displayPrice
    return found
  }

  private func cancelled(_ error: Error) -> Bool {
    if case StoreKitError.userCancelled = error { return true }
    return false
  }

  private func refreshOwned() async {
    var found = ""
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == request.product,
        transaction.revocationDate == nil
      {
        found = result.jwsRepresentation
      }
    }
    receipt = found
    owned = !found.isEmpty
  }

  private func write() {
    let clean = price.replacingOccurrences(of: "\n", with: " ")
    var text = "answer=\(request.number)\nowned=\(owned ? 1 : 0)\nstate=\(state)\nprice=\(clean)\n"
    if owned { text += "receipt=apple:\(receipt)\n" }
    text += "\n"
    FileHandle.standardOutput.write(Data(text.utf8))
  }
}

let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "--check" {
  print("dot-popper-store runs")
  exit(0)
}
guard let text = arguments.first, let request = Request(text) else {
  FileHandle.standardError.write(Data("usage: dot-popper-store 'dotpopper-store://ACTION?n=N&product=ID&file=-'\n".utf8))
  exit(64)
}
// The game going away closes the pipe; writing to it then must end this
// program, not stop it on a signal it ignores.
signal(SIGPIPE, SIG_DFL)
NSApplication.shared.setActivationPolicy(.accessory)
DispatchQueue.main.asyncAfter(deadline: .now() + longest) { exit(0) }
Task { @MainActor in
  await Keeper(request).perform()
  exit(0)
}
NSApplication.shared.run()
