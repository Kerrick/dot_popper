<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# The rules

How a game of Dot Popper plays, as the code has it: the field, the dots and their size, spawning, the score and the clock, the bonus dot, and how time reaches the rules. It is for anyone changing the rules or the code that feeds them. The rules live in `lib/dot_popper/*.rb` and use no Lota, so their tests need no window.

## The field and R

- **R** is a dot's radius. Every distance and speed in the rules is a multiple of it. All dots in a game share one radius.
- **The field** is the whole window: `Field` (`lib/dot_popper/field.rb`), a width, a height and the radius. A dot's center stays between `min_x` and `max_x` (and `min_y`, `max_y`), one radius in from each edge. On a field narrower than a dot, the center line is the only place.
- **Units.** `conf.rb` turns on `t.highdpi`, so Lota's graphics units are logical pixels on a desktop, points on iOS and density-independent pixels (dp) on Android.
- **The standard radius** is `Rules::RADIUS`, 50 units, on every system (`DotSize.for`). The aim is a physical size of about 8 mm. Neither Lota nor LÖVE reports a screen's physical density, so 50 units is the stand-in: 50 points is 7.9 to 9.6 mm on current iPhones and iPads, and 50 dp is 7.9 mm by Android's definition. `DotSize#reason` says which, and the game prints it at launch.

### The desktop window

A desktop window opens at 24 × 16 R, 1200 × 800 units at the standard radius, shrunk to fit within 90% of the desktop, and never under 400 × 320 units (`Style::WINDOW`, `WindowStyle#mode_for` in `lib/dot_popper/presentation/layout.rb`, `Shell::App::SMALLEST_WINDOW`). In the simulator, that field plays like an 11-inch iPad, so a computer and a tablet give comparable games. The player may resize it or go full screen (F11, or Settings' Display). Phones and tablets fill the screen.

## Dots

A dot is a value, `Dot` (`lib/dot_popper/dot.rb`): an `id`, a place, a velocity on each axis, the radius, and whether it is `popped` or a `bonus` dot. Moving or popping a dot gives a new dot with the same id.

- **A new dot** gets a uniformly random center on the field (`Field#random_center`) and, on each axis, a speed from `Rules::SPEEDS` (1.2, 2.4, 3.6, 4.8 or 6.0 R per second) with a random sign (`Field#random_speed`).
- **Moving.** `Dot#move` bounces off the field's edges exactly: a dot that would pass an edge comes back by as far as it went past, however many edges one long frame crosses, so how far a dot travels does not depend on the frame rate.
- **The stack.** `Stack` keeps the dots in drawing order, oldest on top. Each new dot slides in under every dot already there (`Stack#slide_under`). A tap reaches only the topmost dot under the point (`Stack#top_at`), never one beneath it.
- **Hit areas are circles.** `Dot#covers?` tests the dot's radius, whatever the dot looks like or which theme is in use.
- **A popped dot** stays in play and keeps moving for the rest of the game. There is always exactly one bright dot.

## Dot size: Fit the screen and Standard

Why fitting is the default: [ADR-0001](../adr/0001-dots-fit-the-screen-by-default.md).

`DotSizing` (`lib/dot_popper/dot_sizing.rb`) holds the player's choice:

| Choice | Constant | Radius | Saved as |
| --- | --- | --- | --- |
| Fit the screen (the default) | `DotSizing::SIZED_TO_SCREEN`, `DotSizing::DEFAULT` | `DotSize.fitted(width, height)` | `fitted` |
| Standard | `DotSizing::STANDARD` | `Rules::RADIUS`, 50 units | `standard` |

**The formula** (`DotSize.fitted`): R = √(width × height ÷ 384), the radius that makes the field `Rules::FITTED_AREA`, 24 × 16 = 384 square radii, the desktop window's area. It is clamped:

- never below `Rules::SMALLEST_FITTED_RADIUS`, 30 units, a dot 60 points across, well over Apple's 44-point smallest touch target;
- never above `Rules::LARGEST_FITTED_SHARE`, a seventh of the window's shorter side (or 30 units, if that is larger), so a dot on a long, thin window stays a dot.

On an upright phone the floor applies: the exact fit would be about 29.6, so the field is 373 R² rather than 384.

**Saving.** The choice is kept in `dot_size.txt`. It is written only when the player picks a size. `DotSizing.parse` reads `standard` or `fitted`, and `same`, Standard's name in saves from before it was called standard (`DotSizing::EARLIER_NAMES`); a missing, empty or unreadable file means the player never chose, and gets `DEFAULT`.

**When it applies.** `Cabinet#field` gives a new game `sizing.fit(screen)`. A game keeps its radius until it ends. `Cabinet#sizing=` changes the choice only on Home, so a game in play is never resized by it. Speeds are in radii per second, so they scale with R. Buttons and their reaches do not, since they are sized for a finger, not for the field.

**When the choice is offered.** Settings shows a "Dot size" row only where the two radii differ by more than a tenth (`SizingPreview#offered?`, `SizingStyle#alike` of 0.1 in `Style::SIZING`). In a 1200 × 800 window the two are alike, so the row is hidden there; resizing the window brings it back. Each segment is named for what it does on this screen next to the other ("Smaller" or "Bigger", `Words#sizing`), never easy or hard; the fitted choice comes first (`Show::SIZINGS`). Where the row is hidden, the saved choice stands and games follow it. The screen itself is described in [screens.md](screens.md).

**What fitting does not do.** Fitting narrows the difference that screen size makes to how crowded the field gets. It does not make scores comparable across devices: the same player still scores differently on different screens, and differently again with a mouse, a finger or a controller. Friend groups count only games with fitted dots, so every member plays the same kind of game ([friend-groups.md](friend-groups.md)).

Each choice keeps records of its own ([progress.md](progress.md#size-classes)).

## Resizing during a game

When the window changes size or a phone turns (`Shell::App#resize`), `Cabinet#screen=` gives a game in play the new field with the game's own radius, and `Game#field=` moves every dot in proportion (`Dot#refit`): a dot 70% of the way across the old field's room is 70% of the way across the new one's, and the same down. It is then confined to the field, which matters only on a field narrower than a dot. Velocities and the radius do not change, nor do the score and clock. The spawner is rebuilt for the new field. Turning a phone and turning it back puts each dot where it was.

- The next game starts on the new screen, with its radius worked out again.
- A game counts in the size class it started in, even if the window changes during it (`Cabinet::Playing#size_class`).
- Home's drifting dots (`Attract#refit`) and the tutorial's dots move the same way. Where the new screen gives Home's dots a different radius, they are drawn afresh.
- The Game Over pile is a Box2D pile under gravity. Its walls move to the new edges and a dot left outside is brought back in (`Shell::Pile#refit`).

`RulesFuzzTest` resizes and turns the field at random during its games, and checks that every dot keeps its id, order, state and velocity, stays on the field, and moves in proportion, and that the score and clock don't change.

## The spawn check

Why the rule exists, and the maintainer's words that set its scope: [ADR-0002](../adr/0002-a-new-dot-offers-a-touch-target-within-a-second.md).

A bright dot's place and velocity are drawn at random. Then `Spawner` (`lib/dot_popper/spawner.rb`) asks `SpawnCheck` whether the new dot will offer a **touch target** within `Rules::SPAWN_LOOKAHEAD`, one second.

| Number | Constant | Value |
| --- | --- | --- |
| Touch target | `Rules::TOUCH_TARGET` | a circle 44 units across (Apple's smallest touch target, 44 points; 44 logical pixels on a desktop) |
| Look-ahead | `Rules::SPAWN_LOOKAHEAD` | 1.0 s |
| Step | `SpawnCheck::STEP` | 1/30 s, so 31 moments from 0 to 1 s (`STEPS` is 30) |
| Tries | `Rules::SPAWN_TRIES` | 4 velocity redraws, then 4 place-and-velocity redraws |
| Sample spacing | `TouchTarget::SPACING` | 5 units |

**What counts.** A touch target lies wholly on the new dot and clear of every dot above it (touching allowed). It is the same size whatever R is, because a fingertip is.

**The draws.**

1. The first draw stands if the check passes. That is nearly always, and it uses no more randomness than an unchecked spawn, so seeded games replay the same unless a redraw happens.
2. Otherwise the velocity is drawn again, keeping the place, up to 4 times.
3. Then the place and velocity together, up to 4 more times.
4. If every try fails, the last draw stands, so a dot always spawns. `Spawn#exhausted?` says so.

`Spawn` records `velocity_redraws` and `position_redraws`, and `Game#spawns` keeps every spawn's record. `Game.new(..., spawn_tries: 0)` turns the redraws off, so every first draw stands; the simulator uses it to measure the rule.

**The look-ahead.** `SpawnCheck#exposed_soon?` moves the new dot and every dot above it forward with the real `Dot#move`, bounces included, straight to each step's time, and asks at every step. Any opening lasting 1/30 s or longer contains a step; shorter ones are under two frames at 60 Hz, too brief to tap on purpose. Two shortcuts keep it fast:

- A dot above that could not reach the new one before a step is not moved: on each axis two dots close no faster than their two speeds added, so the check skips a dot until the soonest time it could overlap.
- A step stops at the first dot that covers every place a target could go (`TouchTarget#covered_by?`), and that dot is asked first at the next step.

A dot too small to hold a target (under 44 units across, smaller than the rules allow) always passes, since no draw could do better.

**Sampling** (`TouchTarget`). The target's center may lie anywhere within `reach` = R − 22 of the dot's center. `TouchTarget.on(radius)` samples that disc with rings 5 units apart, points about 5 units apart along each ring, every other ring turned by half a point, then the center. The outermost ring comes first, because a partly covered dot is open at its edge. For any radius from 30 to 120, every possible center is within 3.5 units of a sample (`TouchTargetTest`), so a target the check misses had less than 3.5 units to spare around its 22-unit radius. Samples are real centers, so a target it finds is always real.

**Cost** (measured, not enforced). `script/benchmark_spawn.rb` times a spawn with 100 popped dots on the field, in CPU time, on five fields. On the maintainer's Mac:

- On a 27-inch 1440p monitor's field with standard dots, where long games really do reach 100 dots, a spawn took 0.08 ms on average and 0.6 ms at the 99th percentile.
- On an upright phone's field with standard dots, packed with 100 dots, it took 1.7 ms on average and 6 ms at the 99th percentile. There 70% of spawns were redrawn, and 10% used every try and kept their last draw.

A spawn happens once per pop. On a packed phone screen the rule does real work: it finds the gaps that are left and puts the new dot in one when it can. Where no gap exists, the dot spawns as it would have.

Tests: `test/spawner_test.rb`, `test/touch_target_test.rb`.

## Score and clock

`Game` (`lib/dot_popper/game.rb`) holds the dots, the score and the clock, and changes them in place by swapping in new values. Each tap returns an event (`Events::Popped`, `Events::Penalized`, `Events::Missed`); a pop's and a mistake's carry the dots, the score, the countdown and the time played as the tap left them, so no listener reads the game itself.

| | Points | Seconds | Constants |
| --- | ---: | ---: | --- |
| A game starts with | 0 | 10 | `Rules::LOWEST_SCORE`, `Rules::STARTING_SECONDS` |
| Pop a bright dot | +1 | +1 | `POP_POINTS`, `POP_SECONDS` |
| Pop a bonus dot | +4 | +4 | a pop's own plus `Rules::BONUS` |
| A mistake (tap a popped dot) | −2 | −2 | `PENALTY_POINTS`, `PENALTY_SECONDS` |
| Tap empty space | 0 | 0 | |

- **Pop.** The dot becomes a popped dot where it is, and a new bright dot spawns under every dot on the field.
- **Mistake.** The penalty takes at most what the score has, so the score never falls below 0. `Events::Penalized#points` is what was really lost, and `#softened?` says the floor kept part of it from landing. The clock takes the full 2 seconds.
- **The clock** (`Countdown`) counts down in real time and never reads less than zero. The game ends the moment it reaches zero, whether time ran out or a penalty took the last of it (`Cabinet::Playing#settle`).
- **`Game#elapsed`** counts only time the clock was running, and never more than was left on it, so a game plays no longer than its clock. Stats and achievements time a game by it.

## The bonus dot

`Rules::BONUS` is `Rules::Bonus.new(dots_in_a_row: 8, points: 3, seconds: 3.0)`.

- Eight dots in a row without a mistake earn a bonus dot. It is the next bright dot the game spawns, in place of the ordinary one, so there is still one bright dot to pop.
- Popping it pays 3 points and 3 seconds on top of a pop's own: "+4" and "+4s".
- A mistake starts the count over. A bonus dot already earned stays until it is popped. Popping it starts the count over, without counting itself.
- Nothing is random. No draw is made for it, so a seed gives the same dots with the rule on or off.
- `Game#dots_in_a_row` is the count toward the next bonus dot. A game the tutorial played over begins play with the row its popped dots made there (`Cabinet#unpause`), so the dot lit there stays lit, whether the tutorial ended or was skipped. See [tutorial.md](tutorial.md).
- `Game.new(..., bonus: nil)` turns the rule off, as the simulator does to compare.
- `GameStats#bonuses` counts the bonus dots popped.

How the bonus dot and the row of eight look and sound is in [look-and-sound.md](look-and-sound.md).

**How the numbers were chosen** (measured with `bundle exec ruby script/simulate.rb bonus`, 400 games a cell, three devices, dots fitted to the screen). Without a bonus dot the model player scores about 23 points in 34 s on the 24 × 16 R window. A row of 6 lifted scores 30 to 70%, too much of a game being bonus; a row of 10 was a small bump a player might not see in their first games. 8/3/3 gave 29.5 points (+30%), 40 s (+20%), a 90th percentile of 52 s, and no endless games on any device. Seconds beyond 3 lengthened games but barely raised scores, because crowding, not the clock, ends a long game.

Tests: `test/bonus_test.rb`.

## Seeds

Every game has a seed of its own. `Cabinet#start_game` draws one below 2³¹ (`Cabinet::LARGEST_SEED`) from the app's main generator and gives the game a `Random` of its own from it. The game draws from that `Random` only when a dot spawns, so the same seed and the same taps give the same dots, whatever else uses randomness meanwhile; a burst of droplets can't change which dots come next. `DOT_POPPER_SEED` seeds the main generator, which makes a whole session repeatable (developer settings: [doc/README.md](../README.md)). `Events::GameStarted` and `Events::GameEnded` carry the seed, and `games.csv` records it ([progress.md](progress.md#the-games-log)), so any game in a playtest can be replayed.

## Time

### The frame clock

Lota calls `Lota.update(dt)` in `main.rb`, which calls `Shell::App#tick`. The game moves on by the time between the last two frames starting to draw (`Presentation::FrameClock`, read with `Lota::Timer.time` in `Shell::App#draw`), not by Lota's `dt`. The first move uses Lota's `dt`. With no frame drawn since the last move, as in the background, it counts up to now. Every second is counted once, so the clock and the rules keep time with the wall.

The reason is Android: there a frame waits for a free buffer when it starts to draw, after Lota has read its timer, so Lota's `dt` swings about the refresh (7.5 ms, then 25 ms, at 60 Hz on a OnePlus Nord), while every frame reaches the screen evenly. The time between frames starting to draw is even.

The GUI suite's director steps `App#update` by its scenario's fixed step, bypassing `tick` (`test/gui/director.rb`). Tests: `test/presentation/frame_clock_test.rb`.

### The longest frame

`Shell::App#update` clamps each frame's seconds to `Rules::LONGEST_FRAME`, 0.1 s, before the rules, the Show, the pile or the effects use them. A frame that took longer (a window dragged on Windows, a stalled computer, an iPad back from the background) did not give the player that time to play, so it must not take it off the clock. Frame rates down to 10 frames a second are unaffected.

### Game Over's grace

For `Rules::GAME_OVER_GRACE`, 0.9 s, after the clock runs out, Game Over ignores presses (`Cabinet::GameOver#ready?`). A player often taps at a dot in the game's last instant, and without the pause that tap would dismiss the final score unseen. How Play again shows the grace is in [screens.md](screens.md).

## How crowded the field gets

The game's tension, a bright dot appearing under popped ones, depends on how crowded the field gets, and that depends on the field's size in square radii. `script/simulate.rb` plays the real rules with a model player on six screen sizes, with each dot size, and with the spawn rule on and off. The model player waits a reaction time (0.25 s), takes the time Fitts's law predicts to reach the dot, waits while the bright dot is covered, and now and then (a 4% chance per 0.1 s) taps a covered dot anyway. It updates 30 times a second, and a game longer than 240 s counts as endless. The script itself is described in [development.md](development.md).

The model player is crude: its mistakes mostly reflect how impatient it was told to be. Compare rows with one another, not with a person's scores.

### Screen size and dot size

Measured 2026-11-05, before the bonus dot existed (the same as `bonus: nil`), 60 games per row (`bundle exec ruby script/simulate.rb 60`). "Area" is the field in square radii; "Mistakes" is per game.

Standard dots:

| Device | R | Area (R²) | Mean score | 90th percentile | Mean game (s) | Mistakes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 50 | 134 | 6.0 | 12 | 16.5 | 6.6 |
| 11-inch iPad | 50 | 387 | 23.6 | 35 | 34.2 | 8.8 |
| 13-inch iPad Pro | 50 | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Desktop window, 24 × 16 R | 50 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, full screen | 50 | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32-inch 6K monitor, full screen | 50 | 2035 | 76.8 | 103 | 87.6 | 7.2 |

Dots fitted to the screen:

| Device | R | Area (R²) | Mean score | 90th percentile | Mean game (s) | Mistakes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 30.0 | 373 | 21.6 | 33 | 32.2 | 8.6 |
| 11-inch iPad | 50.2 | 384 | 22.2 | 33 | 32.8 | 8.8 |
| 13-inch iPad Pro | 60.7 | 384 | 23.0 | 33 | 33.6 | 8.7 |
| Desktop window, 24 × 16 R | 50.0 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, full screen | 98.0 | 384 | 23.6 | 35 | 34.2 | 7.3 |
| 32-inch 6K monitor, full screen | 115.1 | 384 | 20.3 | 31 | 31.1 | 7.2 |

With standard dots the mean scores run from 6.0 to 76.8, nearly thirteen times apart; an upright phone holds about 15 times fewer square radii than a 6K monitor. Fitted, they fall between 20.3 and 23.6, within 8% of their average. The rest of the spread follows the screens' shapes and the model player's luck.

### How often the spawn check acts

Measured before the bonus dot existed, 200 games per row. "Redrawn" and "Moved" are the shares of spawns whose velocity, and then place, were drawn again. "No target" is the share of spawns without the rule that offered no touch target for a second (the script's "redrawn", "moved", "no target" and "old score" columns).

| Device | Dot size | Redrawn | Moved | No target | Mean score | Mean score without the rule |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | Standard | 1.39% | 0.00% | 1.22% | 6.1 | 5.8 |
| 11-inch iPad | Standard | 0.41% | 0.00% | 0.48% | 24.0 | 23.0 |
| 13-inch iPad Pro | Standard | 0.34% | 0.00% | 0.32% | 33.4 | 33.9 |
| Desktop window, 24 × 16 R | Standard | 0.50% | 0.00% | 0.39% | 23.6 | 21.4 |
| 27-inch 1440p monitor | Standard | 0.20% | 0.00% | 0.19% | 60.9 | 60.0 |
| 32-inch 6K monitor | Standard | 0.13% | 0.00% | 0.10% | 74.9 | 75.9 |
| iPhone, portrait | Fitted, R 30 | 4.97% | 0.05% | 4.72% | 24.1 | 22.0 |
| 11-inch iPad | Fitted, R 50.2 | 0.56% | 0.00% | 0.53% | 24.0 | 23.4 |
| 13-inch iPad Pro | Fitted, R 60.7 | 0.22% | 0.00% | 0.14% | 24.0 | 23.7 |
| 27-inch 1440p monitor | Fitted, R 98 | 0.08% | 0.00% | 0.09% | 22.8 | 23.8 |
| 32-inch 6K monitor | Fitted, R 115 | 0.04% | 0.00% | 0.04% | 21.5 | 22.6 |

On every device but one, fewer than 1 spawn in 70 is redrawn, and a new place is almost never needed. The exception is a phone with fitted dots, where R is 30 and a 44-unit target leaves only 8 units of reach, so about 1 spawn in 20 is redrawn. The two sets of games diverge after the first redraw, so the differences in mean score (−1.0 to +2.2 points) are within the simulation's noise of about a point between seeds, not a measured effect. The model player's games never get as crowded as `script/benchmark_spawn.rb`'s packed phone screen, which is where the rule does most.

## Tests

| What | Where |
| --- | --- |
| Every rule, over thousands of random games with random resizes | `test/rules_fuzz_test.rb` |
| A game: popping, mistakes, the floor, the clock, resuming from the tutorial | `test/game_test.rb`, `test/cabinet_test.rb`, `test/countdown_test.rb` |
| Dots, bounces, refitting | `test/dot_test.rb`, `test/field_test.rb`, `test/stack_test.rb` |
| Dot size and the choice | `test/dot_size_test.rb`, `test/dot_sizing_test.rb`, `test/presentation/sizing_preview_test.rb` |
| The spawn check | `test/spawner_test.rb`, `test/touch_target_test.rb` |
| The bonus dot | `test/bonus_test.rb` |
| The frame clock | `test/presentation/frame_clock_test.rb` |
| The rules' values are shareable, and a game plays in a Ractor | `test/ractor_test.rb` |
