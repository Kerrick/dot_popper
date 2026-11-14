---
status: accepted
date: 2026-11-13
deciders: coding agents, answering a question of the maintainer's (Kerrick Long); he has not reviewed the design
---

# A build for sale carries only its own parts, and the test build's code is a part it leaves out

## Context and Problem Statement

Every package held the same Ruby, whatever it was sold through: the fake store and fake checkout, the test keys with their private halves, the fake setdef server, and the developer settings that grant Pro in a test build. A stamped constant, `Build::CHANNEL`, chose among them, so none of it ran in a build for sale ([ADR-0009](0009-the-store-is-a-port.md), [ADR-0010](0010-pro-comes-only-from-proof.md)), but all of it shipped. The maintainer asked whether a store's build could be made to hold none of the code for selling Pro another way: "I'm curious if it's possible to build such that [...]". A store's reviewer who opens a package should find nothing in it that looks like a second way to pay, or a way to get Pro without paying. What does a package carry, and how is the rest kept out?

## Decision Drivers

* A build for sale holds no code that grants Pro without proof, running or not (ADR-0010's rule, applied to what ships as well as to what runs).
* A test build keeps everything and behaves as before: a playtest runs the game as the final game does (ADR-0009).
* No condition on the channel may ship for code the build doesn't have: a missing file must not be one `if` away from a crash.
* Released tools only ([ADR-0006](0006-lota-fuse-builds-the-desktop-apps.md)): what `lota fuse` can do today.
* A check on the built package, not only on the repository, says whether the rule held.

## Considered Options

1. One build with every adapter and key, chosen by a stamped constant (what there was).
2. Parts: code only some builds carry lives in a folder of its own (`lib/dot_popper/PART/`); `Build::PARTS`, stamped with the channel, names the parts a build loads; shared code answers as a build for sale does, and a part prepends its own answers; a package leaves the other parts' folders out.
3. A gem for each channel's code.

## Decision Outcome

Chosen: option 2, because it alone meets the first driver with released tools. Option 1 ships what the driver forbids. Option 3 was set aside on what `lota fuse` needs: it builds from one lockfile, so a gem per channel would mean a lockfile per channel; `lota fuse --exclude` already leaves out paths, which is all option 2 asks of it. The test build's part is `lib/dot_popper/test_build/`: the test keys and pins, the receipt test key, the fake store, checkout and setdef server, and the settings that grant Pro. The repository's `build.rb` names it, so every playtest kit and CI run is a test build; `script/set_build_channel.rb` stamps a channel's own parts (none, today, for every channel for sale).

Confidence: medium. The Linux packages of every channel for sale and CI's Mac App Store package were measured without the part, and each still plays; the packages were not measured again after the last two moves, and no `app-store` or `google-play` phone build exists yet to measure.

### Consequences

* Good, because a build for sale holds no test key, no fake and no setting that grants Pro, and the Package workflow fails if a file of the part, or a word that names one of those, comes back.
* Good, because a test build is unchanged: it loads the part and trusts, sells and meters as before.
* Bad, because a reader of the shared code doesn't see the test build's answer there: `Continuity.pins_for`, `Receipt.trusted`, `Entitlement.forced?` and the composition root's test-only choices answer for a build for sale, and the part's prepended modules answer for a test build.
* Bad, because a build for sale must be stamped (`CHANNEL` and `PARTS`) or it loads the test build's part; the jobs for sale stamp it, leave the folder out, and check the app they built.
* Bad, because it is half done. Every build for sale still carries the website store and license keys, with the offer's words about them, and every store's receipt code but its own need not be there: each waits on a part of its own, and the receipts on a decision about which receipts a build trusts.
* Bad, because phone builds don't go through `lota fuse`, so each phone workflow keeps its own list of what to leave out.

### Confirmation

Every Package job for sale runs `script/channel_contents.rb check` on the package it built, which fails on a file its channel leaves out, or on a word that names a test key, a fake or a test build's setting, and `script/check_build.rb`, which shows the built app refusing the test build's proofs. `test/channel_contents_test.rb` loads each channel's stamped build without the files it leaves out.

## More Information

What each package holds and leaves out is in [PACKAGING.md](../../PACKAGING.md); how a part is loaded, and which answers the test build's part prepends, in [store and Pro](../design/store-and-pro.md). ADR-0009 chose which adapter a build picks; this decides which adapters it carries. Revisit when the website's part exists, and when the first phone build for a store is made.
