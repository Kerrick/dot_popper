<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# The tutorial and the wordless signs

How Dot Popper teaches itself without a word: the tutorial that opens the first game, and the signs on Home, in a game and at Game Over that teach the same rules elsewhere. It is for anyone changing `Presentation::Tutorial`, its guide, or the signs. [ADR-0003](../adr/0003-how-to-play-is-taught-without-words.md) records why the game teaches this way. The rules it teaches (points, seconds, the penalty, spawning, the bonus dot) are in [rules.md](rules.md).

## What it is

The tutorial is a layer over the first game, played while that game is paused before its clock first runs. There is one game: its dots, score, clock, row and rules are the rules' own, and the tutorial keeps no copy of any of them. It uses the game's real drawing, the slowest real speed for its first dot (`Rules::SPEEDS.min`, 1.2 radii a second), the real HUD with its row of eight dots in a row, and the game's real pop and penalty effects. It says nothing in words: only numbers, the clock's digits, a drawn stopwatch, a small dot and drawn shapes. Nothing in it depends on sound.

While it plays, `Cabinet` holds the game in its `Paused` state ([ADR-0016](../adr/0016-the-tutorial-is-a-layer-over-a-paused-game.md)): the clock does not run, the dots move only as the tutorial moves them, and no press reaches the game except the ones the tutorial passes on. The `Show` draws the tutorial over it (`Show#tutorial?`). When the tutorial ends, or is skipped, it goes, and the same game plays on from the state it is in (see "Play begins").

| Part | Where |
| --- | --- |
| The scene, its beats and its numbers | `Presentation::Tutorial` (`lib/dot_popper/presentation/tutorial.rb`) |
| Its timings and looks | `Style::TUTORIAL` (a `TutorialStyle`), `Style::CALM_WAG` (`lib/dot_popper/presentation/style.rb`) |
| The guide's motion | `Presentation::GhostHand`, `GhostStyle`, `WagStyle`, `GhostPose` (`ghost_hand.rb`) |
| The pointing hand's geometry and PNG sizes | `Presentation::PointingHand` (`pointing_hand.rb`) |
| The spotlight | `Presentation::Spotlight`, `SpotlightStyle` (`spotlight.rb`) |
| Numbers in flight | `Presentation::Flight` (`flight.rb`), drawn as a `Presentation::Tally` (`tally.rb`) |
| Whether pressing Play opens it | `Presentation::TutorialFlag` (`tutorial_flag.rb`), `tutorial.txt` |
| The paused game | `Cabinet::Paused`, `Cabinet#start_paused`, `#press_paused`, `#move_paused`, `#arrange`, `#unpause`; `Game#move_dots`, `#arrange` |
| Opening, skipping and playing on | `Show#play`, `#how_to_play`, `#skip_tutorial`, `#open_tutorial`, `#follow_tutorial`, `#play_on` |
| Drawing | `Shell::TutorialPainter`, `Shell::GhostPainter`, `Shell::HandSprites`, `Shell::TallyPainter`, and `Shell::Renderer#tutorial` |

## When it opens

- **A first Play.** `Show#play` opens it, over a new game (`Cabinet#start_paused`), when `TutorialFlag#due?(played: Show#stats_offered?)` is true. It is due once on a device, and never for a player who has played: a finished game in `stats.txt` (`StatsBook`), or Stats ever cleared (`StatsKeeper#cleared?`).
- **How to play.** Home's How to play button, the H key, and a gamepad's Y on Home open it at once, seen or not (`Show#how_to_play`). Home shows the button only after a game has been played (`HomeScreen#pill_names`), since before that Play opens the tutorial. H works on any Home. How to play opens over a new game exactly as a first Play's tutorial does.
- **`tutorial.txt`** says `seen` from the moment the tutorial opens, by either road, so a skipped tutorial counts as seen (`TutorialFlag#seen!`). Anything else in the file counts as unseen. The file is kept apart from Stats, so clearing Stats leaves it: clearing starts the scores over, not the player.
- **Development.** `DOT_POPPER_TUTORIAL=1` opens it on every Play. `DOT_POPPER_AUTOPLAY`, `DOT_POPPER_SCENARIO` (the GUI director) and `DOT_POPPER_NO_TUTORIAL` leave it out (`TutorialFlag.mode`); `DOT_POPPER_TUTORIAL=1` wins over them, which is how the GUI tutorial scenarios open it.

## Skip

A Skip button stands at the bottom right of the safe area (`Layout#skip_button`), the skip sign (`Glyphs` `:skip`, a triangle and a bar) before the word, so it reads without English. A tap on it, Escape, and a gamepad's B (`Show#back`) skip at any beat. Skip takes the tutorial away, and its game plays on at once from the state it is in, with no lead-in (`Show#skip_tutorial`, `#play_on`): the dots where they are, and the score, the clock and the row as the rules have them. Nothing starts or ends, since the game began when the tutorial opened. What the tutorial had yet to show of the game is shown at once (`Tutorial#catch_up`): a dot the rules popped takes its popped look, a dot they spawned is born, and the HUD reads the game from the next frame. The spotlight, the guide, the numbers in flight and the row's ring go with the tutorial. The maintainer's words: "Skip should skip all the tutorial-y bits being added to the current game, and get out of the way so the player can play."

## The beats

The beat is `Tutorial#beat`. Time in the scene flows at `Tutorial#rate`, from 1 (the game's own speed) to 0 (stopped), and always eases rather than snapping (`Level`).

| Beat | What happens | Ends when |
| --- | --- | --- |
| `:drift` | The first bright dot drifts. | `drift`, 1.0 s, has passed. |
| `:aim` | The player's turn. Time eases to a stop in `stop`, 0.15 s; the spotlight finds the dot; the guide taps it over and over; a ripple opens from the dot (`hand_the_turn_to_the_player`). | The player pops the dot. |
| `:points` | The tap reaches the game, which pops the dot and spawns the next under it. The pop bursts over the dot, still drawn bright, the new dot not yet drawn, and time holds still while its three numbers fly in turn (see "Numbers travel from the dot"). | The last lands, then `hold`, 0.3 s. |
| `:peek` | Time flows again in `resume`, 0.5 s. The dot takes its popped look, with its squash (`Tutorial#settle`), and the new bright dot is born under it, where the tutorial places it (see "How the second dot parts from the first"), and slides out. The spotlight fades. | The two dots' middles are `peek`, 0.8 radii, apart. |
| `:warn` | Time stops. The guide taps the popped dot once, a press the tutorial passes to the game, which charges it: the game's penalty plays, and its cost travels out of the dot (see "The guide's mistake"). | The cost's last number lands. |
| `:slide` | Time flows at `slow`, 0.6. The light moves to the bright dot as it slides clear; the guide wags its finger above. | The dots are `clear`, 2.3 radii, apart and the guide has wagged and settled. |
| `:aim_next` | The player's turn again, marked as at `:aim`. | The player pops the bright dot. |
| `:runs` | The tap reaches the game, which pops the dot and spawns the next bright dot under every dot, from the game's seed. The pop bursts, still drawn bright, and time stops. Its three numbers fly together, in `quick`, 0.45 s, and land at once with a chime and a tick. | `linger`, 0.35 s, after they land. |
| `:ending` | `hand_over`: the dot takes its popped look, the bright dot the game spawned is born under every dot, the light moves to the clock, and time flows again in `handover`, 0.35 s. | `handover` has passed; the beat becomes `:over`. |

A beat that waits for dots to move never waits more than `longest`, 5 s, in case they bounce.

Worked out from `Style::TUTORIAL` (not measured): `:points` takes 1.92 s; in `:warn` the guide's press lands at 0.54 s and the cost's last number at 2.16 s; the guide, arriving above at 2.24 s, has wagged and settled 3.29 s after `:warn` began, so `:slide` lasts at least 1.1 s; `:runs` takes 0.92 s and `:ending` 0.35 s. `:drift` is 1.0 s; `:peek` and the player's turns last as long as the dots or the player take.

### The first dot's start

The first bright dot (`Tutorial::BRIGHT`), which the game is made with (`Game.new`'s `dots`), starts at `start`, an offset of −0.27 of the field's width and −0.12 of its height from the screen's middle, so a little above it and to its left, and drifts left and down at the slowest speed (`Tutorial#first_dot`). It freezes well away from the middle on every window size. A gamepad's cursor starts hidden in the middle of the screen, so a dot there would sit under the guide and the player's cursor alike, and nobody would have to aim. `test_the_bright_dot_freezes_well_away_from_the_middle_where_a_gamepad_cursor_starts` holds it at least 3 radii from the middle, inside the safe area below the margin, and clear of Skip, at every size in `ScreenPlansTest::SIZES`.

### How the second dot parts from the first

The next bright dot (`Tutorial::NEXT`) is the one the game spawned at the first pop. As it is shown born, the tutorial places it `born`, 0.1 radii, from the popped one (`Tutorial#parting`, `Cabinet#arrange`), while the game is paused and before anyone has seen it. Where both have room across, at least 1.15 radii ahead of and behind the popped dot, it goes back the way the popped one came, toward the middle. Where a side wall is too near, as on an upright phone, they part up and down instead: the new dot goes down, and the popped one rises. Either way they part away from where the guide waits above. Placing the dot, and turning the popped one upward, are the only changes the tutorial makes to the game that its rules do not: a paused game's dots may be arranged, a game in play's never are.

## Stopped and flowing time

Time stops for the player to look at one thing: at the player's turns, at each pop while its reward flies, and while the guide's mistake is shown and its cost flies. It flows, slowly, while the bright dot slides clear and the guide wags. While time is stopped, dots do not move.

A pop is seen to take effect when time flows again, not at the tap. The rules pop the dot and spawn a new one at the tap, as in play; the tutorial stops time at exactly that instant, and draws the dot bright and the new one unborn (`Tutorial#dots`) until it moves on, when the darkening and the spawn are shown. This keeps the reward coming from a dot that still looks bright, the dot the player tapped. Feedback comes at the moment of the action, from the thing acted on (Swink, *Game Feel*), and things that change together are read as one (common fate, Johnson, *Designing with the Mind in Mind*).

## Numbers travel from the dot

Every change to the HUD is carried by an object flying from the dot that caused it to where it counts (`Tutorial#one_by_one`, `#fly_in`, `Flight`). Each flight is a `Tally`: a signed number, with a drawn stopwatch after it for the time, or a small dot after it for the row.

| On | From | Flights, in turn | Colors |
| --- | --- | --- | --- |
| The first pop | The tapped bright dot | "+1" to SCORE, "+1" and a stopwatch to TIME, "+1" and a dot to the row | Cream, then mint (`gain`) twice |
| The guide's mistake | The popped dot | "−1" to SCORE, "−2" and a stopwatch to TIME, "−1" and a dot to the row | `alarm` |
| The last pop | The tapped bright dot | The same three as the first pop, all at once | As the first pop |

In turn means each lands before the next leaves: `gap`, 0.12 s, then `flight`, 0.42 s, for each. A flight into the HUD eases in and out and melts into its number at the end (`Flight#progress`, `#alpha`). Each number changes the HUD the moment it lands: a point gained chimes (`:tick` at pitch 1.5), a second gained ticks (`:tick` at 1.0), and a dot joining the row ticks at 1.25. On the first pop the spotlight goes with each number (`light: true`); on the mistake it stays on the dot and the guide. The object carries the cause to the effect (Johnson's common fate; Swink's feedback from the thing acted on), and one thing lands at a time (Hodent, *The Gamer's Brain*).

The mistake's cost is what the game took for the guide's press (the `Penalized` event, `Tutorial#losses`), and a number already at nothing is left out; a pop's numbers are what its `Popped` event earned (`Tutorial#gains`). The HUD shows each number as it lands, so it runs behind the game until the last lands. At that moment the score is 1, so it shows "−1"; the clock is at 11, so "−2"; the row holds one, so "−1".

### Time and the row

The HUD starts at score 0 and 10 seconds, with the game's own row of `Rules::BONUS.dots_in_a_row` (eight) small dots hanging under it, none lit (`Hud#counting`). There is no label and no number for the row, as in the game.

- The first pop's third flight lights the row's first dot, and the row rings mint for `notice`, 0.9 s (`RowNotice`, `TutorialPainter#row_ring`).
- The guide's mistake empties it, and it rings in the alarm's color (`Tutorial#empty_the_row`).
- The last pop lights its first dot again, with no ring.

The rings run under the beat and add no time. What a full row brings is left for the game to surprise the player with: nothing in the tutorial shows or says it (`test_nothing_shows_what_a_full_row_brings`). Fun is finding the pattern (Koster, *A Theory of Fun*), and the row visibly answers each right and mistake (Salen and Zimmerman's meaningful play, *Rules of Play*).

## The guide

The guide is the player's own hand on the input they last used (`Presentation::InputKind`), drawn by `Shell::GhostPainter`:

| Input | The guide |
| --- | --- |
| Touch | 👆, Noto Emoji's backhand index pointing up (U+1F446), in its default yellow, solid |
| Mouse | A pale arrow pointer (85% at most) that shrinks for a moment as it clicks and sends out three short rays |
| Gamepad | A pale copy of the gamepad's reticle, with an A button beside it that goes down as it presses |

**Tapping.** One tap's loop is `loop`, 1.6 s (`GhostHand#tap_pose`): the guide comes in from its rest, `rest` (0.75, 0.9) radii down and to the right of the dot, where it hides none of it, presses, holds, lifts and goes back. A press rings where it lands; the pointing hand sends two thin cream rings out from its fingertip. Moving between places, it glides in `glide`, 0.5 s, easing in and out; it fades in or out in `fade`, 0.25 s.

**The pointing hand.** People recognize a familiar picture far faster than they decode a drawing of one (Johnson, *Designing with the Mind in Mind*), and a player has seen this emoji in every chat. Its yellow names no skin color.

- It stands upright, its fingertip (`PointingHand::TIP_AT`) on the point it taps and the hand below, so it hides only the lower part of the dot. Its picture is `GhostPainter::HAND`, 3 radii square; the hand in it is about 2.8 radii tall (`REACH`).
- Near the right edge it is mirrored, never turned (`PointingHand.facing`). It is never turned upside down; the tutorial's dots stay clear of the bottom.
- As it presses it shrinks by `PRESS`, 6%, as if pushed into the glass.
- LÖVE cannot draw the system's color emoji fonts, and Apple's artwork may not be shipped, so the game ships Noto's, under the Apache License 2.0 ([assets/emoji/README.md](../../assets/emoji/README.md)). Its credit is on the Credits screen (`Style::WORDS.notice`, `:emoji`).

**Its PNGs.** `script/make_hand.rb` renders `assets/emoji/emoji_u1f446.svg`, cut to `PointingHand::VIEW`, into square PNGs `assets/emoji/hand-SIZE.png` of 48, 64, 96, 128, 192, 256, 384 and 512 pixels (`PointingHand::SIZES`), with `rsvg-convert` and ImageMagick. Every clear pixel takes the color of the hand's nearest pixel (`Bleed`), so no dark fringe appears when it is drawn smaller. The game picks the smallest PNG with at least the pixels the hand needs at the screen's density, or the largest (`PointingHand.size_for`), loads it once with mipmaps and linear filtering (`Shell::HandSprites`), and draws it at the size it needs, so it is drawn smaller than its pixels, never larger. A PNG of the exact size cannot be made ahead of time: the hand follows the dot's radius, which follows the screen and the dot-size choice, and it eases smaller as it presses. The frame itself is still drawn at the window's own pixels. `test/presentation/pointing_hand_test.rb` checks every PNG exists at its size, the choice of size, the tip and wrist, and the mirroring.

## The guide's mistake and its wag

As the new bright dot peeks out from under the popped one, the guide taps the popped dot once (`Tutorial#show_the_cost`). As its press lands (`GhostHand::PRESSED` of the loop, about 0.54 s in), the game's own penalty plays (`Tutorial#guide_makes_a_mistake`): the dot's shudder and alarm ring, the dashed outline of the bright dot under it (`Stack#bright_beneath`, `Style::REVEAL`), the edge's glow (`PENALTY_FLASH`), and the bonk, panned to where it happened. Then its cost flies out, in turn. The screen does not shake and no phone buzzes, so it can't be mistaken for the player's own tap. There is no ✕ or other sign forbidding it: symbols and colors are not read alike everywhere (Westland and Maggio, *Universal Principles of Color*), and showing a consequence teaches better than a sign (Hodent).

As the last of the cost leaves, the guide lifts and glides to wait above the popped dot (`Tutorial#waiting_place`): `hover`, 0.2 radii left of it and 4.6 above, so the whole hand hangs clear of both dots, and kept half a radius inside the field's sides so its thumb stays on screen as it wags. There it wags its finger, "no" (`WagStyle#turn`): twice side to side in 0.8 s, turning 0.21 radians (12°) each way about its wrist, the bottom middle of the emoji (`PointingHand::WRIST_AT`), easing in and out. It then holds still for `settle`, 0.25 s. A mouse pointer or a reticle, with no wrist, slides side to side as far instead (`GhostPainter::WAG`). With `DOT_POPPER_CALM=1` the wag is gentler, 0.1 radians (about 6°) over 1.0 s (`Style::CALM_WAG`).

Time stays stopped while the cost flies and flows at 0.6 while the guide wags, so the wait for the next tap is the wag itself. Only once the bright dot is clear and the guide has wagged and settled does it move to the bright dot and tap (`Tutorial#follow`, `@waited_out`). A finger-wag is widely, though not universally, read as "no"; the cost has already shown what the mistake did, so a player who does not read it so loses nothing.

## The player's turn

Only `:aim` and `:aim_next` hear the field (`Tutorial::TURNS`, `Tutorial#players_turn?`). In every other beat, while the guide demonstrates or the scene plays, a tap is not heard at all: no pop, no cost, no ripple, no sound. Skip goes through the `Show` and works at every beat. Touch, the mouse and a gamepad's A all reach the same `Tutorial#tap`, and the primary button (`Show#primary`: Start, or A aimed at no button) does nothing in the tutorial.

On the player's turn (`Tutorial#tap`):

- a tap on the bright dot the beat waits for reaches the game (`Cabinet#press_paused`), which pops it;
- a tap on empty space ripples faintly (`TOUCH_RIPPLE`), as in a game, and does not reach the game;
- a tap on a popped dot does nothing, and does not reach the game. The lesson shows the mistake's cost and never charges it: a learner who taps the wrong dot in a lesson hasn't earned a loss (Juul, *The Art of Failure*). The game's rules are the same as in play; the tutorial simply never passes that press on.

A second tap on a dot that is bursting does nothing, since its beat has moved on. The turn is handed over plainly: time stops, the light finds the dot, the guide goes to it, and a ripple opens from the dot, the one thing on the field that answers (`Tutorial#hand_the_turn_to_the_player`; Saffer, *Microinteractions*, on a plainly marked trigger).

A pop of the player's plays the game's burst, shockwave, pop sound and, on Android, its buzz (`Tutorial#burst`).

## The spotlight

`Spotlight` dims everything but a circle of light: around a dot, 1.5 radii (`dot`); around a HUD number, 0.8 of the HUD's height; around the row, 1.35 of it. It darkens to 62% (`dim`) over a soft edge of 0.9 radii (`feather`) and moves or fades in 0.35 s (`move`). It is drawn under the HUD, which is never dimmed, and a HUD number it lights is haloed in mint. `TutorialPainter#dim_around` draws it as rings of quads, since the window has no stencil.

## Play begins

When the beat is `:over`, `Show#follow_tutorial` takes the tutorial away and unpauses its game (`Show#play_on`, `Cabinet#unpause`). Nothing is copied: the game is the one the tutorial played over, with its three dots where they are and going as they go, the two popped ones on top and the bright one under them; its score, 1, its clock, 10 seconds, and its row, 1, which are always so, since the player's own taps on a popped dot never reach it. The `Show` keeps the tutorial's dot animations, its effects still playing and its HUD, so nothing on screen jumps (`Show#game_started`).

Only the clock starts. Nothing fades, nothing resets and no dot is added. The light on the clock (`LeadIn`, `Style::TUTORIAL.lead`) fades out in 0.6 s, so the game's dots are never hidden for more than a moment, and a halo stays on the clock for 1.3 s, then fades in 0.4 s. While it shows, the clock's first second down ticks. A skip has no lead-in.

`GameStarted` is announced as play begins, at the end or at a skip, so the game's listeners hear nothing of the tutorial's presses while it plays. From there the game plays by the usual rules, and its score, records, Stats, achievements and daily goal count as any game's. `GameStats.opening` counts each popped dot as a pop with no wait, so the score and the dots popped agree; the guide's mistake is not the player's, so it is not counted, and `AchievementWatch` starts its row at the game's. A game the tutorial played over is never reported to a friend group, whether the tutorial ended or was skipped (`Show#game_ended` passes `sized_to_screen: false` for it; see [friend-groups.md](friend-groups.md)).

A demonstration should show what really happens (Hodent), and an ending that carries straight on asks the player to unlearn nothing. The game also keeps the row the tutorial lit, so the last pop's dot does not go out as the game begins, a loss with no mistake (Juul). The maintainer's words: "Keeping a second copy of the game is an implementation detail I didn't pay attention to, and a likely source of many bugs I've reported. I'd rather it simply... be a game. That gets paused to show tutorial-style animations etc."

## What spends a free game

The tutorial's game is a game, and it is spent as it begins, when the tutorial opens, from a first Play or How to play. Its end and Skip start nothing, so they spend nothing. `Show#with_a_game` is the only way into a game: Play, and the opening of the tutorial, go through it. It spends a game (`FreeGames#spend!`) or, with none left, opens the offer of Pro as Play does, so with none left a first Play and How to play open the offer instead of the tutorial, and a first Play's tutorial stays due. See [store-and-pro.md](store-and-pro.md) for the free games themselves.

## Signs that teach elsewhere

### Home's legend

On Home before the first game, under the name and above Play, a legend reminds the player of the scoring in the tutorial's own signs (`Presentation::Legend` in `home_plan.rb`, drawn by `HomePainter#legend` with `Shell::TallyPainter`): a bright dot, then "+1" in cream and "+1" with the stopwatch in mint; under it a popped dot, then "−2" and "−2" with the stopwatch in the alarm's color, the numbers in two columns that line up (`Tally.pop`, `Tally.penalty`). Its type is `TYPE.legend`, 29 at a layout scale of 1. After the first game Home has no legend. A player who has watched "+1" and the stopwatch fly into the HUD recognizes them at once, and recognizing is far easier than recalling (Johnson). The layout is in [screens.md](screens.md).

### The mistake's dashed outline in a game

When a player taps a popped dot lying over a bright dot, because the bright dot is under the tap or its edge touches the tapped dot (`Stack#bright_beneath`), the hidden bright dot's outline is drawn over every dot as a dashed line, the usual drawing convention for an edge out of sight (`Presentation::Reveal`, `Style::REVEAL`): 12 dashes, turning slowly, closing from 1.35 radii onto the dot's rim in 0.22 s and fading over 0.6 s. It follows the dot by id. It is never filled in, so it can't be mistaken for an uncovered bright dot and invite a second mistake. A failure feels fair when the player can see its cause, and this one teaches the stacking rule at the moment it matters. The rest of the penalty's effects are in [look-and-sound.md](look-and-sound.md).

### Game Over replays the mistake on the pile

After a game in which the player tapped a popped dot with a bright dot hidden under it, Game Over replays that mistake on the pile (`Show#replay_mistake`): the popped dot that was hit shudders and its alarm ring flashes, the dashed outline of the bright dot it hid draws, and that bright dot pulses with a soft ring (`SPAWN_RIPPLE`). The marks follow the two dots by id wherever the pile throws them.

- **Which mistake.** The game's last such mistake (`Show#penalized` keeps a `Mistake`). If its bright dot was popped later, or either dot is gone, nothing on the pile shows which dot it was, so Game Over shows nothing and that Game Over isn't counted (`Mistake#among`).
- **How often.** On at most `Style::LESSON.times`, 2, Game Overs ever, counted in `taught.txt` (`Presentation::Tutor`). A file saying `taught` counts as already taught twice; anything unreadable starts over at 0.
- **When.** Once the score has counted up, then twice more 2.4 s apart (`LESSON.every`, `replays`: 3 in all), and then the pile is left in peace.
- **How.** No sound, no shake, and every mark is a thin outline that hides no dot. The marks are drawn at the pile's own depth, under the veil that dims it and under Game Over's card, backing and buttons (`Renderer#draw`), so they read as part of the pile and never cross Continue. Continue works as before.

Failure is the moment a player is ready to learn (Juul), and showing the consequence where it happened teaches better than a sentence about it (Hodent). The player saw the same penalty in the game and in the tutorial, so the replay needs no words. Game Over's layout is in [screens.md](screens.md); the pile is in [look-and-sound.md](look-and-sound.md).

## Tests

- `test/presentation/tutorial_test.rb`: every beat, the first dot's start on every screen size, the flights and their order, the cost and its floors, the wag and its timing, the parting near a wall, the row, the player's turn, taps on popped dots, which never reach the game, the game hearing each pop at its tap, its clock standing still, catching up, and resizing.
- `test/presentation/tutorial_beats_test.rb`: frame by frame on three screens, each beat, the HUD's numbers as they land, the sounds, the flights, the spotlight, the guide and the first two dots' places, and the game that follows.
- `test/presentation/show_tutorial_test.rb`: opening on a first Play and by How to play, never again after Stats are cleared, never for a player who has played, play beginning on the same game, the game counting as any game, Skip by button, Escape and B at several beats, every input on the guide's demonstration, and resizing.
- `test/presentation/games_test.rb`: the free game spent as the tutorial opens, and nothing more at its end or at Skip.
- `test/cabinet_test.rb`: the paused game.
- `test/presentation/tutorial_flag_test.rb`, `test/presentation/tutor_test.rb`, `test/presentation/pointing_hand_test.rb`.
- GUI scenarios, which play the real game ([development.md](development.md)): `test/gui/scenarios/tutorial.rb` (with the mouse, `DOT_POPPER_GUI_INPUT=touch` or `gamepad`), `tutorial_skip.rb` and `how_to_play.rb`.
