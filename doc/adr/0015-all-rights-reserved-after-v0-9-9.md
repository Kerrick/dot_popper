---
status: accepted
date: 2026-11-08
deciders: the maintainer (Kerrick Long)
---

# Dot Popper is all rights reserved after v0.9.9

## Context and Problem Statement

Through the v0.9.9 tag, Dot Popper's code was published under the AGPL-3.0-or-later, and its documentation, sounds and icon under CC-BY-SA-4.0, with a switch in the code (`DotPopper::LICENSING`) between an open and a proprietary build. Pro, a paid feature set, was about to be built. Under what terms is Dot Popper's own work offered from then on?

## Decision Drivers

* The decision was made before any paid feature was built (the record's only stated circumstance; it gives no other reason).
* setdef holds the copyright, so it can license later versions however it chooses.
* Third-party work keeps its own license and its notices.

## Considered Options

1. All rights reserved for Dot Popper's own code, documentation, sounds and icon from after v0.9.9; earlier versions stay available under the AGPL and CC-BY-SA at their tags.
2. Keep the AGPL-3.0-or-later and CC-BY-SA-4.0.

Later research (2026-11-11), not a reason for the choice: other common choices for a paid game are a dual license (the AGPL for anyone, and a commercial license for proprietary uses), or a source-available license that allows reading but not reuse. `doc/publishing.md` separately notes that the App Store's terms add restrictions that the GPL family forbids. The record compares none of these with option 1.

## Decision Outcome

Chosen: option 1, the maintainer's decision. No recorded comparison says it is better than the alternatives; the record states the decision and its timing. Confidence: high that it is in force (`LICENSE`, the Credits screen); the reasons beyond timing are not recorded.

### Consequences

* Good, because nothing in the license conflicts with a store's terms or with selling Pro.
* Good, because the build-time switch between open and proprietary builds is gone, so there is one build.
* Bad, because no one else may change, reuse or redistribute the current code without setdef's permission, and contributions need the maintainer's agreement.
* Neutral, because every packaged app still carries the notices for Lota, LÖVE, Ruby, the fonts, the emoji and the libraries they bring, and Credits shows them.

### Confirmation

`LICENSE` states the terms and the v0.9.9 cut-off; Dot Popper's own files that carry an SPDX header name `LicenseRef-setdef-all-rights-reserved`, and third-party files name their own; `test/presentation/credits_test.rb` tests what Credits shows.

## More Information

Third-party licenses and the stores' requirements are in [doc/publishing.md](../publishing.md); the Credits screen is in [screens](../design/screens.md).
