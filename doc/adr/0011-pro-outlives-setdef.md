---
status: accepted
date: 2026-11-09
deciders: the maintainer (Kerrick Long), who approved the continuity proposal ("Yes.", as the record quotes him)
---

# Pro outlives setdef: license keys, one device at a time, and one test of setdef being gone

## Context and Problem Statement

Copies of Dot Popper reach players that no store controls: setdef's website, itch.io, Homebrew, winget, Linux packages and APKs. Those copies need a way to buy Pro, and a way to keep it on one device at a time without a device identifier. And everything setdef runs (the website, the server that friend groups and license checks use) may one day stop; a player who paid should keep Pro, and the game should keep working, when it does. The continuity proposal the maintainer approved is not in this repository; this ADR records what `doc/decisions.md` recorded of it.

## Decision Drivers

* Pro never depends on a server being up ([ADR-0010](0010-pro-comes-only-from-proof.md)).
* No device identifier, and no counter a player can edit.
* Only something setdef signs may take Pro away.
* The game must be able to tell "setdef is gone" from "this device is offline".
* Apple 3.1.1: an iOS build never sells outside the App Store.

## Considered Options

1. License keys signed with Ed25519 and verified offline against two pinned license-signing keys; one key on one device at a time, moved by a signed server answer and never by its absence; and one test of setdef being gone (no valid signed proof from setdef's server, while at least one of Apple's, Google's and Microsoft's connectivity checks answers as expected), on which other rules hang: a theme opens to everyone by date once setdef has been gone 180 days, and a player may choose another friend-group server.

The record names no other option. Later research (2026-11-11), not a reason for the choice: common alternatives are online activation, where each launch or install asks a vendor's server (which fails the first driver); offline keys with no device limit, as many indie desktop apps sell (simpler, but a shared key works everywhere at once); and a promise to release an unlocking update if the vendor stops, which depends on the vendor still being able to ship one. The record compares none of them with option 1.

## Decision Outcome

Chosen: option 1, the approved proposal. The record gives these reasons for its parts: a key is moved only by a signed "moved" answer, so no answer, a refusal, a bad signature or no internet never removes Pro; the server keeps only a secret's SHA-256, so the key moves without identifying the device; a key entered while setdef is gone is Pro at once, and registers when setdef answers. Confidence: medium. The format and signatures pass the server's published test vectors and Ed25519 verifies in every packaged desktop app's Ruby, but no real payment company, checkout, or production license check has run against this client.

### Consequences

* Good, because a website copy keeps Pro offline, forever, on the device that holds its key, and setdef's absence never locks anyone out.
* Good, because Ed25519 comes from OpenSSL in every build, and a build where it fails to load never decides setdef is gone (`Ed25519.available?` checks a test vector first).
* Bad, because the game reaches setdef's server and three outside connectivity checks at each start, which must be declared ([ADR-0014](0014-privacy-facts-come-from-the-code.md)).
* Bad, because "setdef is gone" is a judgement from a failed proof and a working internet, so a long, targeted outage of setdef's server alone would read as gone until it answers again.
* Bad, because the checkout is a placeholder until a payment company is chosen.
* Bad, for operations, because setdef's keys are pinned in the code (`Continuity::SETDEF_PINS`): keeping the signing keys safe, and keeping `GET /proof` answering, are setdef's duties for as long as it sells Pro, and a key that has to be replaced needs a new build of the game.

### Confirmation

`test/continuity/license_test.rb` and `test/continuity/signatures_test.rb` check keys, signatures and pins; `test/privacy/requests_test.rb` plays every continuity request against a local server. The Package workflow's playthroughs and the Android emulator check fail unless the packaged app prints that Ed25519 verifies the server's test vector.

## More Information

The key format, the requests, the watch, theme dates and Change Server are in [store and Pro](../design/store-and-pro.md).
