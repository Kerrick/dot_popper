---
status: accepted
date: 2026-11-10
deciders: coding agents; the maintainer (Kerrick Long) later asked that every outside party be tested the same way
---

# The store is a port, and the build's channel picks its adapter

## Context and Problem Statement

Pro is sold through several stores (the App Store, Google Play, the Mac App Store, the Microsoft Store, and setdef's website for copies no store controls), and none can be reached from a test: no automated check may reach the real internet, and the real stores need accounts that playtest builds don't have. A playtest must still exercise what a player will see: the offer, buying, restoring, the free-game limit. How does the game talk to a store, and which store does a build get?

## Decision Drivers

* A playtest build runs the game exactly as the final game does: a playtest with switches the final game lacks is not a playtest (the record's words).
* No automated test or check reaches a real store (`AGENTS.md`).
* Nothing a player can set may choose the store ([ADR-0010](0010-pro-comes-only-from-proof.md)).
* The maintainer, on not having chosen a payment company, as the record quotes him: "Why do I have to know to be able to test it? Feathers, Beck, Fowler, Martin, Freeman & Pryce, and others have written about this before."

## Considered Options

1. One port (Freeman and Pryce's ports and adapters; Feathers' seam): a request URL and a whole-state answer, with adapters for the native hosts and helpers (`NativeStore`, `Shell::StoreHelper`), a fake store with its own ledger (`FakeStore`), the website store (`WebsiteStore`), and none (`NoStorefront`); `Storefront.for`, called once in `Shell::App`, picks the adapter from the build's channel alone, and a test build (no channel) gets the fakes.
2. The real store on phones in every build, desktops free, and a fake chosen by an environment variable (`DOT_POPPER_FAKE_STORE=1`) for rehearsals.

## Decision Outcome

Chosen: option 1, because a test build then sells and limits free games through the same code, on the same asynchronous road, as a store build, with nothing on screen saying it is a fake, and no setting selects it. Option 2 was the earlier design; it left playtests unlimited on desktops and let a variable change what a build sells. Confidence: high for the game's half, which one contract suite tests against every adapter; low for the native halves against real stores, which have not been tried.

### Consequences

* Good, because everything above the port (the offer, Buy, Restore, the thanks, `Entitlement`, the free-game count) is one body of code for every store.
* Good, because a new channel is a new adapter, registered by name, with no feature changed, since features ask only `Entitlement#pro?`.
* Bad, because a store build must set its channel (`Build::CHANNEL`) or it ships the fake store; a `v1*` tag fails while it is nil (`script/check_build_channel.rb`), and the store build jobs set it with `script/set_build_channel.rb`.
* Bad, because playtests never touch a real store, so a sandbox purchase on a real phone has to be tried by hand before a store release.
* Neutral, because a developer reaches the port's failures only in a test build, with `DOT_POPPER_FAKE_STORE_FAILS`.

### Confirmation

`test/presentation/store_contract.rb` is one suite of what any adapter must do, run against `FakeStore`, `NativeStore` over a real answer file and a stand-in for the host, and `Shell::StoreHelper`; `test/presentation/storefront_test.rb` checks which adapter each channel and system get. `.github/workflows/release-channel.yml` runs the release checks on a `v1*` tag.

## More Information

The channels, adapters, answers and the offer are in [store and Pro](../design/store-and-pro.md). [ADR-0008](0008-native-features-live-outside-the-ruby-process.md) records how the native adapters reach their stores.
