---
status: accepted
date: 2026-11-10
deciders: the maintainer (Kerrick Long), who set the rule; coding agents, for its application to each store
---

# Pro comes only from proof the game verifies, and a store build ignores developer settings

## Context and Problem Statement

Pro is a purchase. A copy that ships unlocked, or that a player can unlock without buying, costs the sale; a copy that locks a paying player out because a server or a network is down costs their trust. Earlier designs kept the purchase in a save file (`entitlement.txt`) and let developer settings in the environment choose test keys and fake stores. What may grant Pro, and what may a player change that affects it?

## Decision Drivers

* The maintainer's rule, as the record states it: cracking by changing the game's code is inevitable and accepted, but a kitchen-table workaround, such as editing a text file or setting an environment variable, must not grant Pro.
* Pro never depends on a server being up: every check is offline.
* No device identifier and no copy protection beyond this.
* Each store's rules: Apple 3.1.1 and Microsoft Policy 10.8 require their own purchase APIs.

## Considered Options

1. Pro is granted only by proof the game verifies itself, offline, at every launch, and nothing stored: a store's receipt (StoreKit's signed transaction, checked to Apple Root CA - G3; Play's purchase, checked against the app's RSA key), or a website copy's license key (an Ed25519 signature against pinned keys, [ADR-0011](0011-pro-outlives-setdef.md)); and what a build trusts is fixed by its channel when it is built, with a store build dropping every `DOT_POPPER_*` setting not on a short list of harmless ones (`Build::HARMLESS`).
2. Keep the purchase in a save file once a store says it is owned, and never lock it again (the earlier `entitlement.txt`).
3. Verify purchases on setdef's server.

## Decision Outcome

Chosen: option 1, because only it meets the maintainer's rule: an edited save file or a set variable proves nothing, while every check still runs with no network. Option 2 fails the rule outright. Option 3 was set aside earlier, when the record judged that nothing here is worth a server, and it would make Pro depend on one. Confidence: medium. The checks pass and fail as they should against chains and keys made in tests; no real App Store, Play or Microsoft Store receipt has been through them.

The Microsoft Store has no receipt the game can verify: Windows.Services.Store provides no API for an in-app purchase's receipt, and the older API's receipts carry a device ID and are unsupported in desktop apps. So its build trusts Windows' own license, read by the store helper at each launch and accepted only down the helper's pipe, never from a file. Replacing the helper in the package's read-only install folder would grant Pro; that is changing the app's code, which the rule accepts.

### Consequences

* Good, because a refunded store purchase is Free from the next launch, since the store stops handing over its receipt; within a run nothing is taken back.
* Good, because a test build's fakes (`Receipt::TestKey`, `Continuity::TestKeys`) sign real proofs that verify only in a test build, so playtests exercise the same checks.
* Bad, because a store copy is Free for the moment before the store answers at launch, and every new `DOT_POPPER_*` setting is inert in a store build until someone adds it to `Build::HARMLESS`.
* Bad, because an automated run of a store build uses the store's real channel and pins, so a pipeline that wants fakes must run the test build.
* Bad, because no Play purchase proves Pro until the maintainer pins the app's Play key (`Receipt::PLAY_KEYS`); a `v1*` tag fails while it is empty.

### Confirmation

`test/receipt_test.rb`, `test/entitlement_test.rb`, `test/build_test.rb`, `test/shell/store_build_test.rb` and `test/continuity/license_test.rb` check that only verified proof grants Pro, that edited files and test keys prove nothing in a store build, and which settings a store build obeys. `script/check_build_channel.rb` gates `v1*` tags.

## More Information

Each store's receipt, the trusts per channel, and `Build.settings` are in [store and Pro](../design/store-and-pro.md).
