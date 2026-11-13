---
status: accepted
date: 2026-11-05
deciders: the maintainer (Kerrick Long)
---

# Dots fit the screen by default, and Standard is the player's choice

## Context and Problem Statement

The spec fixes a dot's radius, R, as a physical size: about 8 mm, a comfortable touch target. Every distance and speed in the rules is a multiple of R, so how many radii fit on a screen sets how crowded a game gets, and crowding is the game's difficulty. An upright phone holds about fifteen times fewer square radii than a 6K monitor. With R fixed, the screen, not the player, decides how hard the game is. How big should a dot be on each screen?

## Decision Drivers

* A failure must feel like the player's own (Juul, *The Art of Failure*); a hidden handicap that the player can't see or choose is unfair (Garfield, *Characteristics of Games*).
* The challenge must be calibrated (Koster, *A Theory of Fun*): a phone shouldn't start its difficulty curve far above a monitor's.
* One rule that works at both ends of a range beats special cases (Sylvester, *Designing Games*).
* Some players prefer a dot that is the same physical size everywhere.
* A default should suit the player who never opens Settings.

## Considered Options

1. Fit the screen by default: each game's R gives the field the desktop window's area in square radii; Standard, R fixed at 50 units, is a choice in Settings.
2. Standard by default (the spec's rule), with fitting as a choice.
3. Standard only: leave the rules as the spec has them.
4. A fixed-size play area, letterboxed where the screen is bigger.
5. Time rewards scaled by the field's area.

## Decision Outcome

Chosen: option 1, because only it lets every screen play about equally crowded for a player who never changes a setting, while keeping the spec's physical size available to anyone who prefers it. Options 4 and 5 were named and not pursued; option 3 was the overnight default only because changing the rules was the maintainer's call. He made it twice: first fitting as a choice (option 2), then, after playing on an iPhone 13 mini, fitting as the default. The record says he rated the game 2 of 5 with standard dots there and 4 of 5 with fitted ones ("far more enjoyable", as the record quotes him).

Confidence: high that fitting narrows the spread. In `script/simulate.rb` the same model player averages 6.0 to 76.8 points across six screens with standard dots, and 20.3 to 23.6 with fitted dots (2026-11-05). It does not make scores comparable across devices: aiming with a finger, a mouse or a gamepad still differs, and the record withdrew an earlier claim that it did.

### Consequences

* Good, because a phone's first games aren't the unfair kind of hard, and Stats keeps fitted games' records apart, since every screen is about equally crowded with them.
* Good, because one formula serves every screen, with no table of devices.
* Bad, because a dot's physical size varies by screen: on an upright phone it is at its 30-unit floor, 60 points across, which the maintainer found "mostly fine (on the small side)", as quoted.
* Bad, because two sets of records exist (fitted, and Standard by small, medium and large screen), which Stats has to explain.
* Neutral, because where the two sizes are within a tenth of each other, as in the 1200 × 800 window, Settings hides the choice.

### Confirmation

`test/dot_sizing_test.rb` and `test/dot_size_test.rb` check the default and the formula; `test/presentation/sizing_preview_test.rb` checks when the choice is offered. Friend groups count only fitted games ([friend groups](../design/friend-groups.md)).

## More Information

The formula and its limits (`Rules::FITTED_AREA`, `SMALLEST_FITTED_RADIUS`, `LARGEST_FITTED_SHARE`, `DotSizing::DEFAULT`) are in [the rules](../design/rules.md), and the Settings control in [screens](../design/screens.md). Revisit if Lota gains a way to report a screen's physical density, which would let Standard be an exact 8 mm.

**Note, 2026-11-13: the sizes' names on screen.** By the maintainer's decision, the screens now call the default size, which this record calls fitted or sized to the screen, "Standard", and the fixed size, which this record calls Standard, "Bigger" or "Smaller", by what it does on the player's device next to the default. The decision itself is unchanged. The words are in the [glossary](../../GLOSSARY.md) and [screens](../design/screens.md).
