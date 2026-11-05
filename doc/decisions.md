# Decisions made overnight

The maintainer asked for a playable build by morning and for nothing short of a
real blocker to wait on a question. These are the calls made without him, each
with its reason, so any of them can be revisited after playtesting.

## Rules

- **The dot's radius is 50 Lota graphics units everywhere.** With `t.highdpi`
  on, those are logical pixels on a desktop and points (iOS) or dp (Android) on
  touch systems. Neither Lota nor LÖVE reports a display's physical density, so
  the spec's 8 mm touch target falls back to 50 units, which is 7.9 to 9.6 mm on
  current iPhones and iPads and 7.9 mm by Android's definition of a dp.
  `DotPopper::DotSize` holds the choice and its reason.
- **A window resized mid-round keeps its dots on screen.** The spec sizes the
  field when the game starts and says nothing about resizing. A resized window
  gives the round in play the new field, and dots outside it are moved to its
  edge. The next round starts on the new field.
- **Game Over ignores presses for 0.9 s** (`Rules::GAME_OVER_GRACE`), so a tap
  meant for a dot in the round's last instant does not dismiss the final score
  unseen. The spec asks for the flow to feel natural; this is the one timing
  rule added for it.

## The field's size, in radii

Because R is a fixed size, the field's size *in radii* varies about 15 times
between a phone held upright and a 6K monitor, and the game's central tension,
a fresh dot spawning under popped ones, depends on how crowded the field is.
`script/simulate.rb` plays the real rules with a model player (reaction time,
Fitts's law travel, waiting for the fresh dot to come out from under, an
occasional impatient tap) at each size. See its output in the commit that adds
it.

- **The desktop window opens at a reference size of 24 by 16 radii** (1200 by
  800 logical pixels), clamped to the screen, instead of most of the desktop.
  Under the model, that plays like an 11-inch iPad, so the Mac, the Windows PC,
  and the iPad give comparable rounds. The window is still resizable and goes
  fullscreen with F11, so a player can choose a sparser, easier field.
- **Phones are much harder, and the rules are unchanged for them.** An upright
  iPhone is 8 by 17 radii; the model scores about a quarter of what it scores on
  an iPad. Making phones easier needs a rule change (a radius that grows with
  the screen, a fixed arena, or time rewards scaled by area), which is the
  maintainer's call after playtesting, not ours.

Its output on 2026-11-05, 60 rounds per device (`bundle exec ruby script/simulate.rb 60`):

| Device | Area (R²) | Mean score | 90th pct | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: |
| iPhone portrait | 134 | 6.0 | 12 | 16.5 | 6.6 |
| iPad 11" | 387 | 23.6 | 35 | 34.2 | 8.8 |
| iPad Pro 13" | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Reference window 24×16 R | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27" 1440p fullscreen | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32" 6K fullscreen | 2035 | 76.8 | 103 | 87.6 | 7.2 |

The model player is crude (its impatience sets the penalty count), so read the
columns against each other, not as predictions of a person's score.

## Presentation

- **One frame advances the rules by at most 0.1 s.** The spec has the clock
  count down in real time, using each frame's elapsed time. A long frame, such
  as dragging a window on Windows, a heavily loaded machine, or an iPad
  resuming, would otherwise take seconds off the clock while the player could
  not see or touch anything. Normal frames, down to 10 a second, are
  unaffected.
- **The look is "gumdrops at night."** Fresh dots are light, glossy, and
  haloed; popped dots are dark, matte, opaque discs with a light rim and a
  sunken crater, so the two differ in lightness (a 5.4:1 contrast ratio,
  enforced by a test) and in shape, not only in hue. Each dot's halo and shadow
  are drawn with the dot, in stack order, so a popped dot visibly covers a
  fresh one. The icon shows exactly that picture.
- **The sound setting is remembered** in the save folder (`sound.txt`), as is
  the best score (`best_score.txt`).
- **Every shader is optional.** If one fails to compile, the game says so once
  and draws plain shapes that keep the fresh/popped distinction
  (`DOT_POPPER_NO_SHADERS=1` forces this). Lota's CI drew the fused Windows
  build's title with Mesa's software OpenGL, shaders and all; no real Windows
  GPU has run it yet.

## Showing off LÖVE's engine

- **At game over the dots tumble into a pile, with Box2D.** Once time is up the
  rules are frozen and the dots are scenery, so `Shell::Pile` hands each one to
  a `Lota::Physics::World` as a ball of radius R, where it was and going as it
  went, between the window's floor and sides (open at the top). It falls behind
  the dimmed score and settles in about two seconds, and a new round or the
  title throws the world away; nothing in it can touch the score or the clock.
  One Box2D meter is 2 R, so a dot is a ball half a meter across, the size
  Box2D is tuned for. Each step is at most 1/30 s. `DOT_POPPER_CALM=1` makes it
  a slow, soft settle with no bounce. The autoplay bot waits 3.2 s at game over,
  not 1.8 s, so captures show the pile settled.
- **A pop's droplets and a new best's fireworks are LÖVE's ParticleSystem.**
  The hand-rolled droplet pool (and its glow shader) is gone. `Shell::Sparks`
  draws two sprites in code into an ImageData at the screen's density, a soft
  round droplet and a four-rayed twinkle, and gives each Burst look and color
  its own system, since a system's colors run through every particle's life.
  The Burst settings in `look.rb` still decide everything, and
  `Presentation::Emission` turns them into LÖVE's sizes, colors over life,
  speeds, damping, gravity, and spin, so the 0.45 s cap and the low opacity
  hold. Side by side in captures, the new droplets read as the old ones did,
  a little softer; the fireworks now twinkle and spin. With no sprite there are
  no droplets, and play is unaffected.
- **A pop and a wrong tap are heard where they happen.** Each sound is mono, so
  OpenAL can place it: `Shell::Speaker` puts each voice relative to the
  listener on a circle one unit away, at the angle `Presentation::Stereo`
  gives for the tap's x, leaning at most 60% to a side. The distance never
  changes, so neither does the loudness. Other sounds play in the centre.
  There is no spawn sound to pan, and none was added, since that would change
  the game's sound design. The panning was checked by logging each voice's
  position; nobody has listened to it in the hidden session.
- **Fresh dots and droplets cast a soft glow, under the dots.** `Shell::Bloom`
  draws the fresh dots and droplets into a canvas at `pixel_dimensions`, blurs
  it twice each way at half resolution with a five-read separable Gaussian
  (`assets/shaders/blur.glsl`, weights from `Presentation::BlurKernel`), and adds
  it to the night *before* the dots are drawn. Added on top, it washed the
  fresh dot out to yellow and lost its gloss; underneath, every dot stays
  exactly as sharp as before, and the popped dots above a fresh one hide its
  light just as they hide the dot, so the glow never hints at a covered dot.
  No text goes near a canvas. It is off without shaders, a canvas, or with
  `BLOOM.strength` 0. In autoplay a frame took about 4 ms with it and without.
- **A pop buzzes the phone briefly, a wrong tap a little longer.**
  `Lota::System.vibrate` for 15 ms on a pop and 40 ms on a wrong tap
  (`HAPTICS` in `look.rb`; 0 turns either off), so the two feel apart under
  the finger as they sound apart. LÖVE vibrates only on iOS and Android, so
  every other system gets `NoHaptics`. It has not been felt on a device yet.

## Game design

Calls made in the game-design pass, which changes no rule. Each one aims at
the player understanding what just happened to them.

- **A wrong tap shows the fresh dot it was too soon for.** When a penalty lands
  on a popped dot that lies over the fresh dot (the fresh dot is under the tap,
  or its disc touches the tapped one), the fresh dot's outline is drawn over
  everything for 0.6 s, dashed, the drawing convention for an edge out of
  sight, and fading. A failure the player can see the cause of feels fair and
  teaches the core rule at the moment it bit. It is an outline, never a fill,
  so it cannot pass for an uncovered fresh dot and invite a second wrong tap.
  `Stack#fresh_beneath` answers the question; it decides nothing.
- **The first wrong tap ever explains the rule, once.** "Popped dots sit on
  top. Wait for the bright one to slide out." shows under the HUD for 2.6 s,
  and `taught.txt` in the save folder keeps it from showing again. The title's
  legend already teaches the scoring, so this line teaches only the stacking,
  at the one moment the player needs it. It is not a button, and the round goes
  on under it; on a narrow screen the two sentences stack.
- **Game Over says what the round was made of.** Under the score, one quiet
  line, "27 pops · 1 slip · longest wait 4.1 s", and, when the round set no
  new best, how far short it fell ("3 short of your best (27)") in place of
  "Best 27". These are the numbers a player can act on: slips are the
  impatience the game punishes, and the longest wait is how long patience
  was asked of them. `RoundStats` builds them from the rules' events, timed by
  `Round#elapsed`, which counts only the time the clock ran.
- **Every round has a seed of its own, and the playtest log records it.**
  `Game#start_round` takes a `Mode`, whose seed gives the round its own
  `Random`; a free round's seed is drawn from the game's randomness, so
  `DOT_POPPER_SEED` still repeats a whole session. A round's dots no longer
  share a Random with the effects, so a burst of droplets cannot change which
  dots come next. `rounds.csv` gets one line per finished round (README lists
  the columns); it is rewritten whole on each append, as Lota's save folder
  offers no append, which is fine for the few hundred lines a playtest makes.
- **A Daily: one shared round a day.** The title keeps "Tap anywhere to play"
  as the default and adds a small **Daily · Nov 5** pill in the bottom left,
  across from the mute button, whose hit area is at least 2 R each way and
  inside the safe area. Its round's seed is FNV-1a of the local date's
  YYYYMMDD digits (`Mode.seed_for`; String#hash differs between processes),
  and dots draw randoms only when they spawn, so the same day and the same
  taps give everyone the same dots; a test pins today's seed so it can never
  drift. The local date is used, not UTC, so the Daily turns over at the
  player's midnight, as Wordle's does. `DailyBest` keeps only today's best
  (`daily_best.txt`); a daily round also counts toward the all-time best,
  since it is the same game. After a daily round the heading names the day,
  the best line is the day's, and **Share** copies two lines, the date and
  score, then pops, slips and the round's length, with nothing that gives the
  day's dots away. A press on Share only shares; anywhere else continues as
  before, after the same grace. The share line includes the score, which the
  brief's example left out, because the score is the number players compare.

## Code

- **The rules core is type-checked by Steep, strictly.** `sig/dot_popper/`
  holds an RBS signature for every class in `lib/dot_popper/*.rb`, with no
  `untyped`, and `bundle exec rake` runs Steep after the tests with its
  strict diagnostics, so a call Steep cannot type fails the build instead
  of passing silently. `rake test` alone does not need Steep, so a machine
  without it can still run the tests. Steep's gems are cached in
  `vendor/cache` for all three platforms, like the rest. Two things the
  checker asked for changed the code: a `Field` now stores its width,
  height, and radius as floats, as a `Dot` already did, because an integer
  radius could leak into a dot's position through `confine`; and
  `Game#subscribe` with neither a listener nor a block raises at once
  instead of failing on the next event. RBS's core signatures leave out
  `Data#initialize`, so `sig/core/data.rbs` declares it, which lets a
  value's own `initialize` call `super` with keywords.
- **`script/simulate.rb` plays each device in its own Ractor.** The rules'
  values (fields, dots, stacks, clocks, and the tap events) are deeply
  frozen, so a Ractor can read the device list and the rule numbers without
  a copy; each Ractor makes its own `Random`, seeded as the serial run was,
  so its rounds are the same ones, and the script checks that they are.
  `DotSize` was the one value that was not shareable, because its reason
  was a string built at run time; it is now frozen, and a test keeps every
  value shareable. On the night it was written, with the Mac's ten cores
  mostly busy with other work, 60 rounds per device took 154 s one after
  another and 126 s in Ractors (1.2×). The ceiling is low for two reasons:
  the 6K device's rounds alone are nearly a third of the simulated time, and every step of
  a round allocates new values, and Ruby 4.0's garbage collector still
  stops every Ractor to collect.
