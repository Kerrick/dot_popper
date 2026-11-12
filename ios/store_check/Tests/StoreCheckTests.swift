// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
import StoreKitTest
import XCTest

@testable import StoreCheck

/// Drives Store.swift as the game does, through its URLs and answer file,
/// against StoreKit's local test session and DotPopper.storekit.
final class StoreCheckTests: XCTestCase {
  private let product = "com.setdef.dotpopper.pro"
  private static var shared: SKTestSession?
  private var session: SKTestSession!
  private var file: URL!
  private var number = 0

  override func setUpWithError() throws {
    file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("store_answer.txt")
    let url = Bundle(for: Self.self).url(forResource: "DotPopper", withExtension: "storekit")!
    // One session for the whole class: a session replaced between tests
    // left StoreKit failing the next purchase with "unknown".
    if Self.shared == nil { Self.shared = try SKTestSession(contentsOf: url) }
    session = Self.shared
    session.disableDialogs = true
    session.clearTransactions()
  }

  private func request(_ action: String) -> Bool {
    number += 1
    var parts = URLComponents()
    parts.scheme = "dotpopper-store"
    parts.host = action
    parts.queryItems = [
      URLQueryItem(name: "n", value: String(number)),
      URLQueryItem(name: "product", value: product),
      URLQueryItem(name: "file", value: file.path),
    ]
    return DotPopperStore.handle(parts.url!)
  }

  /// Waits for an answer to the latest request that has settled.
  private func answer(_ settled: Set<String>, timeout: TimeInterval = 30) async throws -> [String: String] {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let text = try? String(contentsOf: file, encoding: .utf8) {
        let fields = Dictionary(
          uniqueKeysWithValues: text.split(separator: "\n").map { line -> (String, String) in
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
          })
        if fields["answer"] == String(number), settled.contains(fields["state"] ?? "") { return fields }
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("no settled answer to request \(number)")
    return [:]
  }

  func testOtherURLsAreRefused() {
    XCTAssertFalse(DotPopperStore.handle(URL(string: "https://example.com/")!))
    XCTAssertFalse(DotPopperStore.handle(URL(string: "dotpopper-store://buy")!))
  }

  func testOpeningGivesThePriceAndNothingIsOwned() async throws {
    XCTAssertTrue(request("open"))
    let fields = try await answer(["ready"])
    XCTAssertEqual(fields["price"], "$1.99")
    XCTAssertEqual(fields["owned"], "0")
  }

  func testBuyingEndsOwned() async throws {
    _ = request("open")
    _ = try await answer(["ready"])
    XCTAssertTrue(request("buy"))
    let fields = try await answer(["ready", "failed", "canceled"])
    XCTAssertEqual(fields["state"], "ready")
    XCTAssertEqual(fields["owned"], "1")
  }

  func testABoughtProductIsOwnedAtTheNextOpen() async throws {
    try await session.buyProduct(identifier: product)
    _ = request("open")
    let fields = try await answer(["ready"])
    XCTAssertEqual(fields["owned"], "1")
  }

  func testRestoreFindsAPurchaseAndSaysWhenThereIsNone() async throws {
    _ = request("restore")
    let none = try await answer(["none", "failed"])
    XCTAssertEqual(none["state"], "none", "\(none)")
    try await session.buyProduct(identifier: product)
    _ = request("restore")
    let restored = try await answer(["restored", "none", "failed"])
    XCTAssertEqual(restored["state"], "restored", "\(restored)")
    XCTAssertEqual(restored["owned"], "1")
  }

  func testARefundIsNoLongerOwned() async throws {
    try await session.buyProduct(identifier: product)
    let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == product })
    try session.refundTransaction(identifier: transaction.identifier)
    _ = request("open")
    let fields = try await answer(["ready"])
    XCTAssertEqual(fields["owned"], "0")
  }

}
