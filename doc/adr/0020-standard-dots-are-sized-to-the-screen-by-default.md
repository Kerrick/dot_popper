---
status: accepted
date: 2026-11-13
deciders: the maintainer (Kerrick Long)
---

# Standard dots are sized to the screen by default, and Bigger or Smaller is the player's choice

## Context and Problem Statement

The spec fixes a dot's radius, R, as a physical size: about 8 mm, a comfortable touch target. Every distance and speed in the rules is a multiple of R, so how many radii fit on a screen sets how crowded a game gets, and crowding is the game's difficulty. An upright phone holds about fifteen times fewer square radii than a 6K monitor. With one R for every screen, the screen, not the player, decides how hard the game is. How big should a dot be on each screen?

## Decision Drivers

* A failure must feel like the player's own (Juul, *The Art of Failure*); a hidden handicap that the player can't see or choose is unfair (Garfield, *Characteristics of Games*).
* The challenge must be calibrated (Koster, *A Theory of Fun*): a phone shouldn't start its difficulty curve far above a monitor's.
* One rule that works at both ends of a range beats special cases (Sylvester, *Designing Games*).
* Some players prefer a dot that is the same physical size everywhere.
* A default should suit the player who never opens Settings.

## Considered Options

1. Size dots to the screen by default: each game's R gives the field the desktop window's area in square radii. The spec's size, R at 50 units on every screen, is a choice in Settings.
2. The spec's size by default, with sizing to the screen as the choice.
3. The spec's size only: leave the rules as the spec has them.
4. A play area of one size, letterboxed where the screen is bigger.
5. Time rewards scaled by the field's area.

## Decision Outcome

Chosen: option 1, because only it lets every screen play about equally crowded for a player who never changes a setting, while keeping the spec's physical size available to anyone who prefers it. Options 4 and 5 were named and not pursued; option 3 was the overnight default only because changing the rules was the maintainer's call. He made it twice: first sizing to the screen as a choice (option 2), then, after playing on an iPhone 13 mini, as the default. The record says he rated the game 2 of 5 with the spec's size there and 4 of 5 with dots sized to the screen ("far more enjoyable", as the record quotes him).

Confidence: high that sizing to the screen narrows the spread. In `script/simulate.rb` the same model player averages 6.0 to 76.8 points across six screens with the spec's size, and 20.3 to 23.6 with dots sized to the screen (2026-11-05). It does not make scores comparable across devices: aiming with a finger, a mouse or a gamepad still differs, and the record withdrew an earlier claim that it did.

### Consequences

* Good, because a phone's first games aren't the unfair kind of hard.
* Good, because one formula serves every screen, with no table of devices.
* Bad, because a dot's physical size varies by screen: on an upright phone it is at its 30-unit floor, 60 points across, which the maintainer found "mostly fine (on the small side)", as quoted.
* Bad, because two sets of records exist, which Stats has to explain: one for Standard games, since every screen is about equally crowded with them, and one for the other size by small, medium and large screen.
* Bad, because the other size has no one true name. It is bigger than Standard on a phone and smaller on a big monitor, so the screens name it by what it does on the player's device, and code that can't know the device says `bigger_or_smaller`.
* Bad, because the words in players' save files are older than the names: a saved `fitted` means Standard and a saved `standard` means the other size. Each is mapped in one place, and never rewritten.
* Neutral, because where the two sizes are within a tenth of each other, as in the 1200 × 800 window, Settings offers the choice only to a player who has the other size saved.
* Neutral, because friend groups count every game but the tutorial's, whatever its dot size. The maintainer, 2026-11-13: "Somebody's gonna choose a dot size they like and stick with it, usually. Nobody who does that should be excluded from enjoying friend groups." Until then only Standard games counted.

### Confirmation

`test/dot_sizing_test.rb` and `test/dot_size_test.rb` check the default and the formula; `test/presentation/sizing_preview_test.rb` checks when the choice is offered and which name it gets; `test/saved_dot_size_words_test.rb` holds what each saved word means, byte for byte; `test/use_cases/finish_game_test.rb` checks that a game of either size counts in a friend group. `test/glossary_test.rb` fails on the earlier words for the sizes outside this log and the playtest notes.

## More Information

The formula and its limits (`Rules::STANDARD_AREA`, `SMALLEST_STANDARD_RADIUS`, `LARGEST_STANDARD_SHARE`, `DotSizing::DEFAULT`) are in [the rules](../design/rules.md), the Settings control and what Stats says in [screens](../design/screens.md), and the words in the [glossary](../../GLOSSARY.md). Revisit if Lota gains a way to report a screen's physical density, which would let the other size be an exact 8 mm.

This record restates the former ADR 0001, of 2026-11-05, in the words the screens have used since 2026-11-13. That record called the default "fitted" and the spec's size "Standard", the reverse of today, and had friend groups count only games at the default size. The decision between the options is unchanged.

The names are the maintainer's. He put them forward on 2026-11-13 as something he "_could_ however be convinced" of ("\"Standard\" \"Bigger\" \"Smaller\" where one person usually only sees \"Standard\" and \"Bigger\", or sees \"Standard\" and \"Smaller\""), and, asked which size "Standard" would name, answered: "The one that used to be called \"Sized to screen\"". The code's word follows a question of his the same day: "Why not `bigger_or_smaller`". No other names are recorded as weighed.
