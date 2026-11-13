<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Decision log

Dot Popper's architecturally significant decisions, one per record, in the MADR format. Each says what was decided, the options that were weighed, why, what it costs, and what enforces it. How each area works is in the [design documents](../architecture.md#design-documents); code cites a decision here by number for why, and a design document by path for how.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-dots-fit-the-screen-by-default.md) | Dots fit the screen by default, and Standard is the player's choice | accepted |
| [0002](0002-a-new-dot-offers-a-touch-target-within-a-second.md) | A new dot offers a touch target within its first second | accepted |
| [0003](0003-how-to-play-is-taught-without-words.md) | How to play is taught without words, as the opening of the first game | accepted; Skip and the tutorial's rules superseded by 0016 |
| [0004](0004-steep-checks-the-rules-strictly.md) | Steep checks the rules strictly against RBS signatures | accepted |
| [0005](0005-gui-scenarios-play-the-real-game.md) | GUI scenarios play the real game in real windows, on a driven clock | accepted |
| [0006](0006-lota-fuse-builds-the-desktop-apps.md) | `lota fuse` builds every desktop app, from released tools only | accepted |
| [0007](0007-renderers-per-platform-with-a-relaunch-without-vulkan.md) | Renderers per platform, and a relaunch without Vulkan when it fails | accepted |
| [0008](0008-native-features-live-outside-the-ruby-process.md) | Native features Lota lacks are reached outside the Ruby process | accepted |
| [0009](0009-the-store-is-a-port.md) | The store is a port, and the build's channel picks its adapter | accepted |
| [0010](0010-pro-comes-only-from-proof.md) | Pro comes only from proof the game verifies, and a store build ignores developer settings | accepted |
| [0011](0011-pro-outlives-setdef.md) | Pro outlives setdef: license keys, one device at a time, and one test of setdef being gone | accepted |
| [0012](0012-free-games-20-then-3-a-day.md) | Free games: your first 20, then 3 a day | accepted |
| [0013](0013-players-type-no-text.md) | Players type no text: friend-group members are drawn icons, and codes are digits | accepted |
| [0014](0014-privacy-facts-come-from-the-code.md) | The privacy facts are generated from declarations the tests enforce | accepted |
| [0015](0015-all-rights-reserved-after-v0-9-9.md) | Dot Popper is all rights reserved after v0.9.9 | accepted |
| [0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md) | The tutorial is a layer over the first game, paused, and Skip takes the layer away | accepted |
| [0017](0017-use-cases-hold-the-rules-that-need-two-areas.md) | Use cases hold the rules that need two of the game's areas | accepted |
| [0018](0018-screens-are-objects-on-a-stack.md) | Screens are objects on a stack, and the one on top answers every input | accepted |

## Keeping the log

- A new decision gets the next number; numbers are never reused.
- An accepted decision isn't rewritten: a new ADR supersedes it, and a fully superseded one is deleted (git keeps it).
- Record only the reasons a decision actually had. Alternatives found later are marked as later research, with their date.
- Detailed design, rules and numbers go in a design document under `doc/design/`, not here.
