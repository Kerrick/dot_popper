// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// Buying Pro, with StoreKit 2, which is Swift's alone, so
// this file is Swift beside main.m. Neither Lota nor LÖVE knows a store,
// so the game opens a dotpopper-store: URL (Presentation::Storefront) and
// DotPopperApplication, in main.m, hands it here on the main thread, as
// it does share URLs. The answer goes into the file the URL names, the
// whole state each time, written atomically, which the game reads a few
// times a second (ADR-0008; doc/design/store-and-pro.md):
//
//   answer=7              the number of the request this answers
//   owned=1               whether this player has the product
//   state=ready           loading, working, ready, pending, canceled,
//                         restored, none, failed or unavailable
//   price=$1.99           the store's own, in the player's currency
//   receipt=apple:<JWS>   while owned, the transaction as StoreKit signed
//                         it (jwsRepresentation), which the game
//                         verifies itself (Receipt::Apple)
//
// Only a transaction StoreKit has verified, and that was not refunded,
// counts as owned, and "owned" alone grants nothing: the game takes Pro
// only from the receipt. Owned purchases come from
// Transaction.currentEntitlements, which StoreKit answers from the
// device's cache, so #open asks it first and a launch with no internet
// still finds Pro. There is no server, so nothing else checks it.
import Foundation
import StoreKit

@objc(DotPopperStore)
public final class DotPopperStore: NSObject {
  private static let scheme = "dotpopper-store"

  /// Takes a dotpopper-store: URL, and answers NO to any other, so
  /// DotPopperApplication can pass those on. Call it on the main thread.
  @objc(handleURL:)
  public static func handle(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == scheme,
      let action = url.host,
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let product = items.first(where: { $0.name == "product" })?.value,
      let file = items.first(where: { $0.name == "file" })?.value,
      let number = items.first(where: { $0.name == "n" })?.value.flatMap({ Int($0) })
    else { return false }
    let request = StoreRequest(action: action, product: product, file: file, number: number)
    Task { @MainActor in StoreKeeper.shared.perform(request) }
    return true
  }
}

struct StoreRequest {
  let action: String
  let product: String
  let file: String
  let number: Int
}

/// What this game knows of its one product, and the file to tell it in.
@MainActor
final class StoreKeeper {
  static let shared = StoreKeeper()

  private var productID = ""
  private var path = ""
  private var number = 0
  private var owned = false
  private var receipt = ""
  private var state = "loading"
  private var price = ""
  private var product: Product?
  private var listener: Task<Void, Never>?

  func perform(_ request: StoreRequest) {
    productID = request.product
    path = request.file
    number = request.number
    listen()
    Task {
      switch request.action {
      case "open": await open()
      case "buy": await buy()
      case "restore": await restore()
      default: state = "failed"; write()
      }
    }
  }

  /// Hears purchases that finish outside a request: Ask to Buy approved
  /// later, a purchase on another device, a refund.
  private func listen() {
    guard listener == nil else { return }
    listener = Task {
      for await update in Transaction.updates {
        if case .verified(let transaction) = update {
          await transaction.finish()
        }
        await refreshOwned()
        write()
      }
    }
  }

  private func open() async {
    state = "loading"
    write()
    await refreshOwned()
    write()
    do {
      product = try await Product.products(for: [productID]).first
      if let product { price = product.displayPrice }
      state = product == nil ? "unavailable" : "ready"
    } catch {
      state = "unavailable"
    }
    write()
  }

  private func buy() async {
    guard let product else {
      state = "failed"
      write()
      return
    }
    state = "working"
    write()
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
          NSLog("Dot Popper: StoreKit could not verify the purchase: %@", String(describing: error))
          state = "failed"
        }
      case .pending:
        state = "pending"
      case .userCancelled:
        state = "canceled"
      @unknown default:
        state = "failed"
      }
    } catch {
      NSLog("Dot Popper: the purchase failed: %@", String(describing: error))
      state = canceled(error) ? "canceled" : "failed"
    }
    write()
  }

  /// Restore Purchases. AppStore.sync can ask the player to sign in, so it
  /// runs only when the player asks; #open sees past purchases without it.
  private func restore() async {
    state = "working"
    write()
    do {
      try await AppStore.sync()
      await refreshOwned()
      state = owned ? "restored" : "none"
    } catch {
      state = canceled(error) ? "canceled" : "failed"
    }
    write()
  }

  private func canceled(_ error: Error) -> Bool {
    if case StoreKitError.userCancelled = error { return true }
    return false
  }

  private func refreshOwned() async {
    var found = ""
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == productID,
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
    var text = "answer=\(number)\nowned=\(owned ? 1 : 0)\nstate=\(state)\nprice=\(clean)\n"
    if owned { text += "receipt=apple:\(receipt)\n" }
    do {
      let url = URL(fileURLWithPath: path)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(text.utf8).write(to: url, options: .atomic)
    } catch {
      NSLog("Dot Popper: could not write the store's answer: %@", String(describing: error))
    }
  }
}
