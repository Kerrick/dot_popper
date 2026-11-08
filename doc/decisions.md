# Decisions made overnight

The maintainer asked for a playable build by morning, and asked that only a real blocker should wait for his answer. So the agents working overnight made a number of calls on their own. This page records each one for him to review after playtesting.

Each entry says what was decided, why, and what it would take to reverse it. The entries are grouped by the part of the game they affect. A few terms recur throughout:

- **The spec** is the maintainer's description of the game's rules.
- **R** is a dot's radius. Every distance and speed in the rules is a multiple of it.
- **The field** is the area the dots move in, which is the whole window.
- **A fresh dot** is the one bright dot that can be popped for points. **A popped dot** is one already popped, which stays on screen and costs points if tapped again. A tap on a popped dot is a **wrong tap**.

## Rules

### A dot's radius is 50 units on every system

`conf.rb` turns on Lota's `t.highdpi` setting. With it on, Lota measures graphics in logical pixels on a desktop (pixels after the system's display scaling), in points on iOS, and in density-independent pixels (dp) on Android. The game sets R to 50 of those units everywhere. `DotPopper::DotSize` holds the choice and its reason.

**Why:** The spec asks for a touch target of about 8 mm. Neither Lota nor LÖVE can report a screen's physical density, so the game cannot work out how many units make 8 mm. Fifty units comes close: 50 points is 7.9 to 9.6 mm on current iPhones and iPads, and 50 dp is 7.9 mm by Android's definition of a dp.

**To reverse:** If Lota gains a way to report physical density, `DotSize.for` could compute an exact size from it. Because every other distance is a multiple of R, nothing else would need to change.

### A window resized during a round keeps every dot where it was, in proportion

When the window changes size mid-round, or a phone or tablet is turned, the round in progress switches to the new field, and each dot moves in proportion: a dot 70% of the way across the old field's room (from `min_x` to `max_x`, the span its centre may take) is 70% of the way across the new one's, and the same down. It is then confined to the field, which only matters for a field narrower than a dot. Velocities are in radii per second and don't change, nor does the radius. The next round starts on the new field as usual. The title's drifting dots move the same way. The heap of dots at the end of a round is a Box2D pile under gravity, and is still only moved back inside the window (`Shell::Pile#refit`).

At first, a resize moved only the dots left outside the new field to its edge. The maintainer's iPhone playtest found the flaw: on a tall phone, "rotating 'bunched up' all the dots and rotating it back left them all 'bunched up'". Turning a 375 × 812 field to 812 × 375 squeezed every dot into the bottom 375 units, and turning it back left them there. In proportion, turning back puts each dot back where it was. `RulesFuzzTest` now resizes and turns the field at random during its rounds, and checks that every dot keeps its id, order, state and velocity, stays on the field, and moves in proportion, and that the score and clock don't change.

**Why:** The spec sizes the field when the game starts and doesn't mention resizing; this was a decision from earlier, not the spec's. Leaving dots outside the window would make them impossible to tap, and freezing the old size would leave part of the window empty. Moving every dot in proportion keeps the picture the player was reading, gaps and overlaps alike, as near as the new shape allows.

**To reverse:** In `Round#field=`, map the dots with `confine(field)` instead of `refit(old, field)`, which puts back the edge-only behaviour; or change `Game#screen=` (which `Shell::App#resize` calls) to keep the old field until the next round.

### The Game Over screen ignores taps for 0.9 seconds

For 0.9 seconds after time runs out, the Game Over screen ignores presses. The constant is `Rules::GAME_OVER_GRACE`.

**Why:** A player often taps at a dot in the round's final instant. Without the pause, that tap would dismiss the final score before the player had seen it. The spec asks for the flow between screens to feel natural, and this is the only timing rule added for that reason.

**To reverse:** Set `GAME_OVER_GRACE` to 0.

### A new dot is never hidden for its whole first second

This is a change to the spec's rules, approved by the maintainer after the first iPad playtest, in his words: "The rule change, if we do it, should only apply when velocity and position would cause there to be no HIG-compliant touch target within, say, 1 second."

A fresh dot's place and velocity are drawn at random, as the spec has it. Then `Spawner` asks `SpawnCheck` whether the new dot will offer a **touch target** within one second (`Rules::SPAWN_LOOKAHEAD`). A touch target is a circle 44 units across (`Rules::TOUCH_TARGET`, Apple's smallest touch target of 44 points, and 44 logical pixels on a desktop) that lies wholly on the new dot and clear of every dot above it. The check moves the new dot and every dot above it forward with the real `Dot#move`, bounces included, and asks at every 1/30 s step. If a target fits at any step, the draw stands. That is nearly always the case, and it uses no more randomness than before, so seeded rounds and replays play exactly as they did unless a redraw happens. If no target fits, the velocity is drawn again, keeping the place, up to four times (`Rules::SPAWN_TRIES`), and then the place and velocity together, up to four more times. If every try fails, the last draw stands, so a dot always spawns.

How the check works, and what it costs:

- `TouchTarget` samples where the target's centre may go: rings 5 units apart, with points 5 units apart along each ring. Every possible centre is within 3.5 units of a sample, at any radius from 30 to 120. A target it finds is always real, and one it misses had less than 3.5 units to spare around its 22-unit radius.
- Any opening lasting 1/30 s or longer contains a step. Shorter ones are two frames at 60 Hz, too brief to tap on purpose.
- A dot above that is too far away to reach the new one before a step isn't moved. On a full screen, a step stops at the first dot that covers every place a target could go.
- `script/benchmark_spawn.rb` times a spawn with 100 popped dots on the field, in CPU time on the maintainer's Mac. On a 27-inch monitor's field, where long rounds really do reach 100 dots, a spawn takes 0.08 ms on average and 0.6 ms at the 99th percentile. On an upright phone's field packed with 100 dots, where nearly every draw fails, it takes 1.7 ms on average and 6 ms at the 99th percentile. A spawn happens once per pop.

**Why:** In the iPad playtest, a bright dot spawned almost wholly under a popped dot moving at nearly the same velocity, and stayed hidden until the clock ran out. Nothing the player did could have saved that round. Juul (*The Art of Failure*) argues that failure is worth enjoying only when the player can see it was their own, and this loss wasn't. Garfield (*Characteristics of Games*) separates the luck a player can respond to from luck that decides the outcome alone, and this was the second kind. The rule is as narrow as the maintainer asked: it only acts when the new dot would offer nowhere to tap for a whole second, so waiting for the fresh dot to come out from under the others is still the game.

**How rarely it applies:** `script/simulate.rb` now plays every device twice, with the rule and without it (`Round.new(..., spawn_tries: 0)`). These results are from 200 rounds per row. "Redrawn" and "Moved" are the shares of spawns whose velocity, and then place, were drawn again. "No target" is the share of spawns without the rule that offered no touch target for a second. In the script's output these are the "redrawn", "moved", "no target", and "old score" columns.

| Device | Dot size | Redrawn | Moved | No target | Mean score | Mean score without the rule |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | standard | 1.39% | 0.00% | 1.22% | 6.1 | 5.8 |
| 11-inch iPad | standard | 0.41% | 0.00% | 0.48% | 24.0 | 23.0 |
| 13-inch iPad Pro | standard | 0.34% | 0.00% | 0.32% | 33.4 | 33.9 |
| Desktop window, 24 × 16 R | standard | 0.50% | 0.00% | 0.39% | 23.6 | 21.4 |
| 27-inch 1440p monitor | standard | 0.20% | 0.00% | 0.19% | 60.9 | 60.0 |
| 32-inch 6K monitor | standard | 0.13% | 0.00% | 0.10% | 74.9 | 75.9 |
| iPhone, portrait | sized, R 30 | 4.97% | 0.05% | 4.72% | 24.1 | 22.0 |
| 11-inch iPad | sized, R 50.2 | 0.56% | 0.00% | 0.53% | 24.0 | 23.4 |
| 13-inch iPad Pro | sized, R 60.7 | 0.22% | 0.00% | 0.14% | 24.0 | 23.7 |
| 27-inch 1440p monitor | sized, R 98 | 0.08% | 0.00% | 0.09% | 22.8 | 23.8 |
| 32-inch 6K monitor | sized, R 115 | 0.04% | 0.00% | 0.04% | 21.5 | 22.6 |

On every device but one, fewer than 1 spawn in 70 is redrawn, and a new place is almost never needed. The exception is a phone with dots sized to the screen, where R is 30 and a 44-unit target leaves only 8 units of room, so about 1 spawn in 20 is redrawn. The mean scores with and without the rule differ by −1.0 to +2.2 points. The two sets of rounds diverge after the first redraw, so that difference is within the simulation's noise, not a measured effect. With 200 rounds a row, the model player's scores vary by about a point between seeds.

**When the screen is really full:** The model player's rounds never get that crowded, so `script/benchmark_spawn.rb` tests it directly, with 100 popped dots on an upright phone's field. There, 70% of spawns are redrawn and 10% use every try and keep their last draw. So on a packed screen the rule does real work: it looks for the gaps that are left and puts the new dot in one when it can, which makes a packed screen somewhat kinder than the spec's rule would. That is the case the maintainer asked for, since a dot that can't be tapped for a second is the unfair failure. When no gap exists at all, the dot spawns as it would have, and the tries cost about 1.7 ms on average and 6 ms at worst.

**To reverse:** Set `Rules::SPAWN_TRIES` to 0. Every first draw then stands, which is exactly the spec's rule, and `Round#spawns` still says which spawns would have been redrawn. To remove the code as well, have `Round#spawn` call `Dot.spawn` again, and delete `Spawner`, `SpawnCheck`, `TouchTarget`, and `Spawn`.

## How crowded the field is

The rules fix R as a physical size, so the number of radii that fit on a screen changes a great deal from one device to another. An upright phone holds about 15 times fewer than a 6K monitor. That matters because the game's central tension, a fresh dot appearing underneath popped ones, depends on how crowded the field gets.

To measure the effect, `script/simulate.rb` plays the real rules with a simulated player on several screen sizes. The simulated player waits a human reaction time, takes the time Fitts's law predicts to move to a target, waits while the fresh dot is covered, and now and then taps impatiently anyway. The three decisions below come from its results.

### The desktop window opens at 24 × 16 radii

The window opens at 1200 × 800 logical pixels, which is 24 × 16 R, shrunk if the screen is smaller. Before this decision, it filled most of the desktop.

**Why:** In the simulation, a field of that size plays like an 11-inch iPad. That means a Mac, a Windows PC, and an iPad give comparable rounds and comparable scores. The window can still be resized or made fullscreen with F11, so a player who wants a roomier, easier field can have one.

**To reverse:** Change `WINDOW` in `lib/dot_popper/presentation/look.rb`.

### Phones are much harder, and the rules don't change for them

An upright iPhone is 8 × 17 R. On that field, the simulated player scores about a quarter of what it scores on an iPad. The rules were left as they are.

**Why:** Making phones easier would need a change to the rules themselves: a radius that grows with the screen, a fixed-size play area, or time rewards scaled by the field's area. That is a design decision for the maintainer to make after playtesting, not one to make overnight.

**To reverse:** Not applicable; this is a decision not to act. Any of the three changes above would be a new rule.

**Later:** The maintainer approved the first of those changes as a choice for the player, not a new default. See the next entry.

### The player may choose to size the dots to the screen

Once a round has been played, the title shows a button in its bottom row (on an upright phone, in a row of its own just above). It read "Dots: same size everywhere" or "Dots: sized to your screen" (since reworded; see "The dot-size choice says what it does on this screen"), and a tap switches between the two. The title's dots and its best score change at once to match. Either shoulder button on a controller does the same. The choice is saved in `dot_size.txt` in the save folder.

- **The standard dot size** is the default, and it is exactly the spec's rule: R is `DotSize.for(os)`, 50 units on every system.
- **Dots sized to the screen** sets R when each round starts, to the radius that gives the field an area of 24 × 16 = 384 square radii, the desktop window's area: R = √(field area ÷ 384). R is never smaller than 30 units, so a dot is 60 points across, comfortably over Apple's 44-point smallest touch target. It is never larger than a seventh of the screen's shorter side, so that on a long, thin window a dot stays a dot. The numbers are `FITTED_AREA`, `SMALLEST_FITTED_RADIUS`, and `LARGEST_FITTED_SHARE` in `rules.rb`, and `DotSize.fitted` and `DotSizing` apply them.

A round keeps its radius until it ends. If the window is resized during a round, the dots are kept on screen but stay the same size, and the next round works out its radius again. Speeds are still in radii per second, so they scale with R. Rings, droplets, and floating numbers scale with the round's dots too. Buttons and their tap areas don't change, because they are sized for a finger, not for the field. Because every screen is about equally crowded with this choice, its rounds keep bests of their own (`SizeClass::FITTED`, shown as "Your bests with dots sized to the screen"), apart from the small, medium, and large classes. The Records screen explains the choice in one line, and a shared result says "Played with dots sized to the screen."

The words never call either choice easy or hard. They say what each choice does.

**Why:** The simulation (below) shows the screen deciding the difficulty: the same model player averages 6 points on an upright phone and 77 on a 6K monitor. That works against several ideas the game is built on:

- Juul (*The Art of Failure*) argues that failure is worth enjoying only when the player can blame it on themselves. A phone player who loses to a crowded screen they didn't choose can't.
- Garfield (*Characteristics of Games*) separates luck and skill, which players can see, from a handicap that is hidden. Screen size is a hidden handicap: nothing tells the player it is there.
- Koster (*A Theory of Fun*) says the challenge must be calibrated. With R fixed, a phone starts its difficulty curve far above a monitor's.
- Nguyen (*Games: Agency as Art*) describes games as chosen constraints. Making the field's size a setting the player picks turns an accident of hardware into one of those choices.
- Sylvester (*Designing Games*) favours one rule that works at both ends of a range over special cases. One formula fits a phone and a 6K monitor alike, with no table of devices.

The spec's rule stays the default, and it changes only when the player chooses. The setting is a choice rather than the new rule because R is meant as a physical size, and some players will prefer dots that feel the same everywhere.

**To reverse:** Remove the button from `TitlePainter` and the tap from `Show#tap`, and delete `dot_size.txt`. With the saved choice gone, `DotSizing.parse` returns `STANDARD`, which is the spec's rule. The fitted bests stay in the saved files but are no longer shown.

**Later:** After the iPhone playtest, the maintainer made dots sized to the screen the default. See the next entry.

### Dots fit the screen unless the player chooses Standard

This is the maintainer's call, after his iPhone 13 mini playtest of v0.8.3. A new player, and anyone without a saved choice, now plays with dots sized to the screen (`DotSizing::DEFAULT`). The spec's fixed 50-unit radius, about 8 mm, is the other choice, **Standard**. The title's "Dot size" control lists them in that order. Each segment has its name, **Fit the screen** or **Standard**, and under it, in smaller type, what it does on this screen next to the other: on a phone, fitting reads **Smaller, more room** and Standard **Bigger, less room**; on a big monitor, the other way about. The control is still hidden where the two sizes are within a tenth of each other.

`dot_size.txt` is written only when the player taps a segment, and only when the choice changes, in every version since the choice was added. So a file that says `same` always records a player who switched to fitted dots and back to the standard ones, an explicit choice, and it is kept. A missing, empty, or unreadable file means the player never chose, and gets the default.

**Why:** On the iPhone 13 mini, an upright field of about 7.5 × 16 R, the maintainer rated the game 2 out of 5 on the standard dots ("WAY harder on this device until I turn on smaller dots. Like, unenjoyable so.") and 4 out of 5 on the fitted ones ("far more enjoyable"). The dots then "felt mostly fine (on the small side)", at the 30-unit floor, 60 points across. The simulation agrees (see "What the simulation found"): on an upright phone the model player averages 6.0 points with standard dots and 21.6 with fitted ones, and fitted scores on every screen fall between 20.3 and 23.6, against 6.0 to 76.8 with standard dots. A default should suit the player who never opens the settings, and the standard size made the first rounds on a phone the unfair kind of hard (Juul, Koster).

**What it changes for players who never chose:** their rounds now count among the fitted bests, not the small, medium, or large ones, so a desktop player who had bests in "medium" starts a fresh set. The old bests stay in `best_score.txt` and show again with Standard. In a 1200 × 800 window the two sizes are alike, so the control is hidden there; resizing the window brings it back.

**To reverse:** Set `DotSizing::DEFAULT` to `STANDARD`, and put `STANDARD` first in `Show::SIZINGS`.

### What the simulation found

These results are from 2026-11-05, with 60 rounds per device for each choice of dot size (`bundle exec ruby script/simulate.rb 60`). "R" is the radius in graphics units, "Area" is the field's size in square radii, and "Penalties" counts wrong taps per round.

With the standard dot size (the spec's rule):

| Device | R | Area (R²) | Mean score | 90th percentile | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 50 | 134 | 6.0 | 12 | 16.5 | 6.6 |
| 11-inch iPad | 50 | 387 | 23.6 | 35 | 34.2 | 8.8 |
| 13-inch iPad Pro | 50 | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Desktop window, 24 × 16 R | 50 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, fullscreen | 50 | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32-inch 6K monitor, fullscreen | 50 | 2035 | 76.8 | 103 | 87.6 | 7.2 |

With dots sized to the screen (the default since the iPhone playtest):

| Device | R | Area (R²) | Mean score | 90th percentile | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 30.0 | 373 | 21.6 | 33 | 32.2 | 8.6 |
| 11-inch iPad | 50.2 | 384 | 22.2 | 33 | 32.8 | 8.8 |
| 13-inch iPad Pro | 60.7 | 384 | 23.0 | 33 | 33.6 | 8.7 |
| Desktop window, 24 × 16 R | 50.0 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, fullscreen | 98.0 | 384 | 23.6 | 35 | 34.2 | 7.3 |
| 32-inch 6K monitor, fullscreen | 115.1 | 384 | 20.3 | 31 | 31.1 | 7.2 |

Sized to the screen, the mean scores fall between 20.3 and 23.6, within 8% of their average of 21.9. With the standard dot size they run from 6.0 to 76.8, nearly thirteen times apart. On the phone, the smallest radius applies: the exact fit would be 29.6, so its field is 373 R² rather than 384, a little more crowded than the others, though its score is still within the range. The rest of the spread follows the screens' shapes and the model player's luck, not their size.

The simulated player is crude. In particular, the number of penalties mostly reflects how impatient it was told to be. Compare the rows with one another rather than reading them as predictions of a person's score.

## Presentation

### One frame advances the rules by at most 0.1 seconds

The game normally runs the clock down by however much time passed since the last frame. A single frame now passes on no more than 0.1 seconds (`Rules::LONGEST_FRAME`).

**Why:** Some frames take far longer than usual: dragging a window on Windows, a heavily loaded computer, or an iPad returning from the background. Without a limit, such a frame would take seconds off the clock while the player could neither see nor touch anything. Ordinary frame rates, down to 10 frames a second, are unaffected.

**To reverse:** Remove the `clamp` at the top of `Shell::App#update`.

### The look is "gumdrops at night"

Fresh dots are light, glossy, and surrounded by a soft glow. Popped dots are dark, matte, opaque discs with a light rim and a sunken crater. Each dot's glow and shadow are drawn together with the dot, in stacking order, so a popped dot visibly covers a fresh one beneath it. The game's icon shows exactly that picture.

**Why:** The two kinds of dot must be easy to tell apart for every player, including in greyscale and with colour blindness, so they differ in lightness and in shape, not only in hue. The contrast ratio between a fresh dot's body and a popped dot's top is about 5.4:1, and a test in `test/presentation/color_test.rb` keeps it at 4.5:1 or more.

**To reverse:** The colours are in `PALETTE` in `look.rb`. The contrast tests would need loosening for any palette with less difference in lightness.

### The sound setting and the best score are remembered

The game saves whether sound is on in `sound.txt`, and the best score in `best_score.txt`, both in the save folder.

**Why:** A player who mutes the game shouldn't have to mute it again every time it starts.

**To reverse:** In `Shell::App#load`, give the `Speaker` and `BestScore` a store that keeps nothing.

### The night reaches past the last whole unit, and the game says what its window is

The iPhone 13 mini playtest found a thin magenta strip at the right edge in landscape, whichever way the phone was turned. In an iPhone 13 mini Simulator (iOS 26.1), the game now prints one line as it starts and on every resize: landscape reads `screen 811x375 units, 2338x1080 pixels, dpi scale 2.88 (native 2.8793), safe area 49,0,711,355, mode 812x375 fullscreen desktop, usedpiscale true`, and portrait `374x811 units, 1080x2338 pixels, dpi scale 2.8829 (native 2.88), mode 375x812`. The window is 812 points wide but Lota's dimensions are 811 units, rounded down from 2338 ÷ 2.88 = 811.8, and the game's own screenshots show the last two columns of pixels (2336 and 2337) black in landscape, and 1078 and 1079 in portrait. Drawing the night a unit past the dimensions, and clearing each frame to the night's darkest ink (`Renderer#cover`, `Renderer#prepare`), doesn't reach them, so they lie outside what LÖVE draws to: the game can't paint them. The edge glow draws nothing at alpha 0, the bloom is off and draws only where it adds light, and the HUD stays in the safe area. With `DOT_POPPER_DIAGNOSTIC_COLORS=1` (doc/ios.md, "Diagnostic colours") the game clears every frame to pure blue, and those two columns still stay black, so not even LÖVE's clear reaches them, and the host's green behind SDL's view never shows. The rest is for Lota: what LÖVE draws to stops a fraction of a unit short of the drawable. The game keeps the wider night and the clear color, which cost nothing, in case a device's viewport reaches a fraction further.

**Why:** The line lets a run on the real phone be set beside the Fledge SDL test program's on the same phone, and costs one line per start or turn.

**To reverse:** Drop `App#report_screen`, and `Renderer#cover` for `G.dimensions`.

### Every shader is optional

If a shader fails to compile, the game prints a warning once and draws plain shapes instead. The plain shapes still keep fresh and popped dots distinct. Setting `DOT_POPPER_NO_SHADERS=1` forces this fallback.

**Why:** Shader compilers differ between graphics drivers, and a driver that rejects a shader shouldn't stop anyone from playing. On Lota's CI, a build of the game made with `lota fuse` ran a 45-second autoplay round on a Windows runner with no graphics card, using Mesa's software OpenGL, with its shaders working. No real Windows graphics card has run the game yet.

**To reverse:** Not recommended; the fallback costs nothing when the shaders work.

## Showing off LÖVE's engine

Several features exist partly to show what LÖVE's engine can do from Ruby. None of them can change the score or the clock.

### At Game Over, the dots tumble into a heap, using Box2D

Once time is up, the rules stop and the dots become scenery. `Shell::Pile` hands each dot to a `Lota::Physics::World` (LÖVE's binding of the Box2D physics engine) as a ball of radius R, at its last position and with its last velocity. The world has walls at the window's floor and sides and is open at the top. The dots fall behind the dimmed score and settle in about two seconds. Starting a new round or returning to the title screen discards the world.

Box2D works best with objects around a metre across, so one Box2D metre is set to 2 R, which makes a dot a ball half a metre across. Each physics step covers at most 1/30 of a second. With `DOT_POPPER_CALM=1`, the dots fall slowly and settle without bouncing. The autoplay bot waits 3.2 seconds at Game Over, so that its screenshots show the heap after it settles.

**Why:** It is a satisfying ending, and it uses a part of LÖVE that a game like this would otherwise never touch.

**To reverse:** Stop subscribing `@pile` to the game in `Shell::App#load`. The physics settings are `PILE` and `CALM_PILE` in `look.rb`.

### Pop droplets and new-best fireworks use LÖVE's particle systems

The game's own droplet code, and the shader that made the droplets glow, were replaced with LÖVE's `ParticleSystem`. `Shell::Sparks` draws two small images in code when the game starts: a soft round droplet and a four-pointed twinkle. It then gives each kind of burst its own particle system, because one particle system runs all its particles through the same colours over their lifetime.

The burst settings in `look.rb` still decide everything. `Presentation::Emission` translates them into LÖVE's terms (sizes, colours over time, speeds, damping, gravity, and spin), so the existing limits still hold, such as droplets lasting at most 0.45 seconds and staying faint. Side by side in screenshots, the new droplets look like the old ones, a little softer, and the fireworks now twinkle and spin. If the images can't be made, no droplets appear, and play is unaffected.

**Why:** LÖVE's particle systems do the same job with less code in this repository.

**To reverse:** The earlier droplet code is in the history before commit `fbc14b9`.

### A pop or a wrong tap sounds from where it happened

Each sound effect is mono, so OpenAL, LÖVE's audio library, can place it in stereo. `Shell::Speaker` places each sound on a circle one unit from the listener, at the angle `Presentation::Stereo` works out from where the tap was across the screen, and never more than 60% to one side. Because the distance never changes, neither does the loudness. All other sounds play from the centre.

**Why:** Sound placed where the eye is looking helps a player connect the sound to its cause. There is no sound for a new fresh dot appearing, so there is nothing to place there, and adding one would have changed the game's sound design.

**Not yet checked:** The positions were confirmed by logging them, but nobody has listened to the panning, because the work was done in a session with no speakers.

**To reverse:** Set `stereo:` in `SOUND` in `look.rb` to a spread of 0.

### Fresh dots and droplets cast a soft glow beneath the dots

`Shell::Bloom` draws the fresh dots and droplets into an offscreen canvas at the screen's full pixel resolution, blurs it at half resolution with a Gaussian blur (`assets/shaders/blur.glsl`, with weights from `Presentation::BlurKernel`), and adds the result to the background *before* any dots are drawn.

**Why:** When the glow was added on top of the dots, it washed the fresh dot out to yellow and hid its shine. Drawn underneath, it leaves every dot exactly as sharp as before. It also respects the stacking: popped dots on top of a fresh dot hide its glow just as they hide the dot, so the glow never gives away a covered fresh dot. No text is drawn near the canvas, so text stays sharp. In autoplay, a frame took about 4 ms with the glow and about 4 ms without it.

The glow is off when shaders are off, when a canvas can't be made, or when `BLOOM.strength` in `look.rb` is 0. It is now off by default; see "A fresh dot's edge is its hit circle".

**To reverse:** Set `BLOOM.strength` to 0.

### Phones buzz briefly on a pop and a little longer on a wrong tap, but only on Android

The game calls `Lota::System.vibrate` for 15 ms on a pop and 40 ms on a wrong tap. The lengths are `HAPTICS` in `look.rb`, and setting either to 0 turns it off. Only Android buzzes. Every other system, iOS included, gets `NoHaptics`, which does nothing.

**Why:** Two different buzzes let a player feel the difference between a pop and a mistake, just as they hear it. LÖVE can vibrate only on iOS and Android. On iOS, LÖVE ignores the length it is given and plays the system's long vibration (`common/ios.mm` in LÖVE's source), so on an iPhone each pop's buzz would run into the next, and iPads have no vibration motor at all. A short tap on iOS would need Apple's `UIImpactFeedbackGenerator`, which neither LÖVE nor Lota exposes.

**Not yet checked:** Nobody has felt it on a device.

**To reverse:** Add `"iOS"` to `BUZZING_SYSTEMS` in `Shell::Haptics`, or remove `"Android"` to turn haptics off everywhere.

### On a phone or tablet, the game fills the screen and the keyboard only mutes

Where a desktop sizes its window, `Shell::App` on a phone or tablet calls `set_fullscreen` instead. On iOS, that hides the status bar and makes a swipe from the screen's edge need a second swipe before the system acts on it, so a tap near the edge stays a tap. Escape and the fullscreen keys do nothing on a touch device, because an iOS app never quits itself. Only **M**, which mutes, still works.

**Why:** A game played with the whole screen shouldn't lose taps to system gestures. [doc/ios.md](ios.md) has the rest of what an iOS build needs: support for every orientation, an Ambient audio session set by the app's host program, and no entitlements.

**To reverse:** Remove the `@touch` checks in `Shell::App#load` and `#key_pressed`.

## Game design

These calls were made in a game-design pass that changed no rules. Each one aims to help the player understand what just happened to them.

### A wrong tap shows the fresh dot it was too soon for

Sometimes a player taps a popped dot that is lying over the fresh dot, either because the fresh dot is under the tap or because its edge touches the tapped dot. When that happens, the game draws the hidden fresh dot's outline on top of everything for 0.6 seconds, as a fading dashed line. A dashed line is the usual drawing convention for an edge that is out of sight. `Stack#fresh_beneath` finds the hidden dot; it only answers the question and changes nothing in the rules.

**Why:** A failure feels fair when the player can see its cause, and this one teaches the game's central rule at the moment it mattered. The outline is never filled in, so it can't be mistaken for an uncovered fresh dot and invite a second wrong tap.

**To reverse:** Stop `Show` from adding the reveal effect when a penalty arrives.

### The first wrong tap ever explains the rule, once

*Replaced: the rule is now taught on Game Over (see "The stacking rule is taught on Game Over, not in play").*

The first time a player ever taps a popped dot, a hint about the stacking rule appears under the score for 2.6 seconds. The file `taught.txt` in the save folder records that it has been shown, so it never appears again. The hint is not a button, and the round carries on underneath it. On a narrow screen its two sentences stack on two lines.

**Why:** The title screen already explains the scoring, so the hint covers only the stacking, and only at the one moment a player needs it.

**To reverse:** Remove the `Tutor` from `Shell::App#load`. Deleting `taught.txt` shows the hint again.

### Game Over says what the round was made of

Under the final score, one quiet line gives three numbers: how many dots were popped, how many wrong taps there were, and the longest wait for a fresh dot. When the round didn't set a new best, the line under it says how far short of the best the score fell, instead of just showing the best.

**Why:** These are the numbers a player can act on. Wrong taps measure the impatience the game punishes, and the longest wait shows how much patience the round asked for. `RoundStats` builds the numbers from the events the rules announce. It times them with `Round#elapsed`, which counts only the time the clock was running.

**To reverse:** Stop the Game Over screen from drawing the summary line.

### Every round has its own seed, and the playtest log records it

`Game#start_round` takes a seed, which gives the round its own random number generator. An ordinary round's seed is drawn from the game's main generator, so `DOT_POPPER_SEED` still makes a whole session repeatable. Because a round no longer shares its generator with the visual effects, a burst of droplets can't change which dots come next. Each finished round adds one line to `rounds.csv`; the README lists its columns.

**Why:** A recorded seed makes any interesting round in a playtest replayable.

When the columns change between versions (the `mode` column went with the daily challenge, and `goal` and `goal_met` arrived with the daily goal), a log whose first line doesn't match the current columns is saved whole as `rounds-<date>-<time>.csv`, and a new `rounds.csv` starts under the current header. Lota's save folder can't rename a file, so "saving whole" means writing a copy and then starting the log afresh. A CSV whose rows disagree with its header would mislead anyone comparing playtests, and keeping the old file loses nothing.

**Limitation:** Lota's save folder can't append to a file, so the log is rewritten whole each time. That is fine for the few hundred lines a playtest produces.

**To reverse:** Stop subscribing the `PlaytestLog` to the game in `Shell::App#load`.

### Lifetime stats are kept beside the best score, not in place of it

After every round, `Lifetime` adds the round's numbers to totals and bests that cover every round played on the device, and saves them in `lifetime.txt` in the save folder. The totals are rounds, pops, wrong taps, seconds played, and the number of different days played. The bests are the longest round, the most pops in a row without a wrong tap, the fastest pop (the shortest time a fresh dot was on screen before it was popped), and the longest wait that still ended in a pop. The file also keeps the last 20 scores. The numbers come from `RoundStats`, which now also counts the round's score and its runs of pops without a wrong tap. The best score stays in `best_score.txt`, where it has always been, because the rules read it to decide "New best!", and one number should have one home.

**Why:** A player who comes back wants to see that they are improving, and a single best score hides most of that. The file is plain `key=value` lines, read leniently: a line that can't be read keeps its starting value, so a damaged or missing file costs some numbers, never the game.

**To reverse:** Remove `lifetime:` from the `Show` in `Shell::App#load`; the Show then keeps the stats only in memory. Deleting `lifetime.txt` starts them from nothing.

### Bests are kept separately for small, medium, and large screens

Every round now belongs to a size class, worked out from the area of its field in square radii when the round starts (`DotPopper::SizeClass`). A field under 250 R² is small (an upright phone is 134). A field of 700 R² or more is large (a big monitor fullscreen is 1,475 to 2,035). Everything in between is medium: an 11-inch iPad, a 13-inch iPad Pro, and the 24 × 16 R desktop window, at 384 to 566. The cut-offs are `SMALL_FIELD_BELOW` and `LARGE_FIELD_FROM` in `rules.rb`. They sit in the wide gaps between those devices, so resizing a window a little doesn't move it to another class. A round counts in the class it started in, even if the window is resized during it.

The best score and the four other bests (the longest round, the most pops in a row, the fastest pop, and the longest wait) are kept for each class. "New best!" and "New record" compare a round only with earlier rounds in its class, and a class's first round sets no record. The totals, the chart of the last 20 scores, and the daily goal's streak still cover every round. The Records screen shows the bests of the screen it's opened on, under the heading "Your bests on screens this size", with a line under the main heading such as "This screen is about 12 dots wide and 8 dots tall." "Copy my result" ends with a similar line: "Played on a screen about 12 dots wide and 8 dots tall." The dots are counted side by side, so a 24 × 16 R screen is 12 dots wide.

Saved files from earlier versions still load. A `best_score.txt` holding one number, and a `lifetime.txt` with bests that have no class, give those bests to the class of the screen the game opens on. The files are rewritten in the new form at once, so the old bests stay in that class whichever screen the game opens on next.

**Why:** The simulation shows that the same player scores about 6 on a phone, 21 to 24 on a tablet or the desktop window, and 77 on a 6K monitor. Comparing those numbers would tell a phone player that they are bad at the game when the screen is the real cause. Juul's point in *The Art of Failure* is that a failure should feel like your own fault, and that is only fair when the comparison is fair. The totals and the chart stay overall because they describe how much and how often someone plays, which isn't a contest. A player who moves between screens can see the jump in the chart and know why.

**To reverse:** Have `SizeClass.of` always return `MEDIUM`. All the bests then share one class, and the saved files keep working.

### Game Over names one lifetime record, the most impressive

When a round beats one of the lifetime bests, Game Over adds one line under the round's summary, in the gain colour, once the score has finished counting: for example "New record: 18 pops in a row without a wrong tap". If the round beat several, only the most impressive is named, in this order: pops in a row without a wrong tap, then the longest round, then the longest wait that ended in a pop, then the fastest pop. The best score isn't on that list, because "New best!" already says it. "Copy my result" puts the same line between the score and the round's numbers.

A player's first round sets no record, since there is nothing yet to beat. Neither does a round that only matches a best as the game shows it: a round's length counts in whole seconds, and a wait in tenths, so "New record" always shows a bigger number than before.

**Why:** The order puts skill before luck. A long run without a wrong tap is exactly the patience the game asks for, and it is what makes a round last. A fast pop mostly means a dot happened to appear in the open. One line keeps the screen quiet; a list of four records would bury the score.

**To reverse:** The order is `LifetimeStats::Record::ORDER`. To drop the line, stop `FinalePainter` from drawing it and pass no `record:` to `share_text`.

### The Records screen opens from the title, and lives outside the rules

The title screen has a **Your records** button in its bottom left corner, across from the mute button and as tall as it; its tap area is at least a dot's width (2 R) across. It opens a screen over the title's dimmed dots: the heading "Your records", then the player's bests, their totals, and a bar chart of their last 20 scores, and at the bottom "Tap anywhere to go back". On a wide window the bests take the left column and the chart and totals the right; on a narrow one they stack. Each row has its label on the left and its number on the right, so the numbers line up and can be scanned down. The chart is one colour, the fresh dots' amber, with the highest score brighter and labelled with its number. It has no axes or gridlines, and twenty places for bars, so it fills up as rounds are played. Escape also goes back; on a desktop it no longer quits from this screen.

The button appears only once a round has been finished. A first-time player's title still says only what the dots are and "Tap anywhere to play"; a button for records they don't have yet would be one more thing to read before playing.

The screen belongs to the presentation, not the rules: `Show` keeps it open while the game stays on its title, and a tap there only closes it, so it can never start a round or touch a score. The layout is worked out without Lota in `Presentation::RecordsLayout` and tested at sizes from 400 × 320 to 2560 × 1440.

**Why:** The lifetime stats are only worth keeping if the player can see them. A separate screen is a mode, which Saffer's *Microinteractions* advises making obvious when it can't be avoided, hence the heading, the much darker veil, and the standing instruction to go back. Rows rather than tiles because people scan rather than read (Redish), and lined-up numbers group by proximity before a word is read (Johnson).

**To reverse:** Stop `TitlePainter` from drawing the button and `Show#tap` from opening the screen; nothing else depends on it.

### A daily goal, judged by the player's own round, replaces the daily challenge's purpose

Each local date picks one goal from a list of seven in `DotPopper::DailyGoal::LIST`, using a fixed hash of the date (32-bit FNV-1a of "2026-11-05"), so the goal is the same all day, on every device, and in every run. Ruby's own `String#hash` changes from run to run, so it couldn't be used. A goal is met within a single round, judged from that round's `RoundStats` when it ends. The goals, as the title says them:

- "Pop 15 bright dots in a row without tapping a popped one."
- "Pop a bright dot that has been on screen for at least 3 seconds."
- "Pop 10 bright dots in the first 10 seconds of a round."
- "Keep one round going for 40 seconds."
- "Finish a round with 20 points even after tapping a popped dot."
- "Score 25 points in one round."
- "Score 10 points in a round without ever tapping a popped dot."

The title shows the day's goal as one line of plain words, balanced over two lines on a narrow screen, and "✓ Today's goal is done." once it is met. The round that first meets it adds "You met today's goal!" between "Time's up!" and the score, with a small burst of twinkles, once the score has counted up. The game keeps a streak of days in a row with the goal met, and the longest streak, in `lifetime.txt`. The title mentions the streak only from two days on ("You've met the daily goal 3 days in a row."); a missed day starts the count again without a word. `rounds.csv` logs each round's goal and whether it met it. Like the Records button, the goal appears only after the player's first round.

**Why:** The cut daily challenge (below) promised a shared puzzle that the game can't deliver. A goal judged only against the player's own round needs no shared screen: a 15-pop run is just as hard to earn on a phone as on a monitor, relative to everything else on that screen. Most goals reward the game's real skill, patience, rather than a surface reward bolted on (Ferrara's *Playful Design*). The one speed goal, 10 pops in the first 10 seconds, applies while the field is still nearly empty, so it doesn't invite wrong taps. The streak is kept quiet, and losing it costs nothing, because a reward for coming back can crowd out the reason to play (Nguyen), and a failure should feel fair (Juul).

**How the targets were set:** a model player like the one in `script/simulate.rb` played 300 rounds on the 24 × 16 R window. It met a 15-pop clean run in about half its rounds and 25 points in about a third, so those stayed as suggested. It lasted 45 seconds in only 2 to 6% of rounds, so that goal became 40 seconds (about 30%). It almost never waits three seconds on a dot, but a person can choose to, so that target stays as a deliberate test of patience. The model taps fast and slips often, so its figures for the no-wrong-tap goals mean little; 10 points without a wrong tap is a modest round for a careful player.

**To reverse:** Remove `daily_goal` from `TitlePainter` and `goal_met` from `FinalePainter`; the streak would then stay at zero. The list and its targets are in `DailyGoal::LIST`, and the words in `goals:` in `Look::WORDS`. Changing the hash, or the list's order or length, changes which goal every date gets.

### Cut: the daily challenge

For a while the title screen had a second button, "Play today's challenge". Its round's seed came from the local date, so everyone who played on the same day got the same sequence of new dots: the same starting places, directions, and speeds. The game kept the day's best score, and afterwards a button copied the day's result to share. The idea was Wordle's: one puzzle a day, the same for everyone, so that players have something to compare and a reason to come back.

It was removed, because the sameness it promised never reached the screen. Only the *sequence* of spawns was shared. A new dot appears the moment the last one is popped, and every popped dot keeps drifting, so where each new dot lands among the others depends on exactly when the player tapped. After a couple of pops, no two players' screens looked alike, and neither did one player's two tries at the same day. The scores didn't compare across devices either: positions are fractions of the field, and the field's size in radii, which sets how crowded and how hard a round is, varies about fifteen times between a phone and a large monitor. Wordle works because everyone faces an identical puzzle and gets one attempt, and the daily round had neither.

So it was a mode, and a button, for a difference the player couldn't feel. The game's uncertainty comes from the player's own timing, which no seed can fix (Garfield and Costikyan call this kind *performative*). Modes cost attention (Saffer), surface rewards that aren't backed by the play are shallow (Ferrara), and a small game is better for cutting what doesn't earn its place (Sylvester, Schreier). The title is back to one instruction, "tap anywhere to play", and every round is the same kind of round. Each round keeps a seed of its own, for the playtest log.

**Copy my result stays,** on every Game Over rather than only after a daily round, because a new best or a neat round is worth showing someone however it was started. It copies two lines: the score, whether it set or tied the best, and the round's pops, wrong taps, and length. Gamepad **Y** does the same.

**If a shared challenge ever returns,** it needs what Wordle has. The field would have to be the same size in radii on every device (a fixed field, letterboxed where the screen is bigger), so that the same seed makes the same crowd. And each player would get one attempt a day, so the score is a single performance on a shared puzzle rather than a best of many tries.

### A tap on a title-screen dot pops it, but still starts the round

The title screen has seven dots drifting behind its text. The brief proposed making the title a toy: a tap on a title dot would pop it without scoring, and only a tap on empty space would start a round. Instead, a tap on a fresh title dot shows its pop (droplets, ring, and sound) and starts the round in the same instant. A tap on a popped title dot just starts the round. The title pop is scenery: it scores nothing, and its ring doesn't follow any dot in the round. The mute button still responds to its own taps.

**Why:** The brief's version would break the title screen's one instruction, "tap anywhere to play". With seven dots on screen, a player's first tap lands on one fairly often (about one tap in sixteen on the desktop window, more on a phone). The most inviting target, a bright dot, would then be the one place where a tap doesn't start the game. An instruction that holds only most of the time is a hidden mode, which Dan Saffer's *Microinteractions* warns against, and a player's first few seconds are when trust is easiest to lose.

**To reverse:** To get the brief's version, change `Show#tap` so that a tap on a fresh title dot calls `toy_pop` without calling `game.press`.

**Later:** With the dedicated buttons ("Each screen goes on by a button, not a tap anywhere"), the title no longer says "tap anywhere", so the reason above is gone: a tap on a fresh title dot now pops it for fun and starts nothing, as the brief first proposed.

### Each screen goes on by a button, not a tap anywhere

Approved by the maintainer after his iPhone 13 mini playtest ("maybe we should have dedicated buttons not click-anywhere UI"). The title's "Tap anywhere to play" is now a large **Play** button, Game Over's "Tap to continue" a large **Continue** button with **Copy my result** under it, and the Records screen's "Tap anywhere to go back" a **Back** button in the corner where "Your records" was pressed, across from "Clear my records…". Empty space does nothing on those screens; on Game Over a press there is only for the pile, which a quick click or tap no longer leaves. A tap on a fresh title dot pops it, for fun. Play and Continue are the one warm, filled pill on their screens, a fresh dot's gold with its word in ink (`Shell::PrimaryButton`), at least a dot across (2R tall; on a desktop window too short for that, as small as a button) and nearly the width of a phone, and a press reaches them a margin past their edges (`Layout#primary_size`, `#primary_reach`). Continue is faint during Game Over's 0.9-second grace and ignores presses until it ends, as the tap did. Every button lights under the mouse and shows the pointing hand. The words are "Play", "Continue" and "Back", or "Play (A)", "Continue (A)" and "Back (B)" with a controller.

Enter or Space presses the screen's main button (Play, Continue, or Back); Escape, and Android's Back, go back from the Records screen and on from Game Over to the title, after its grace. A gamepad's **A** or **Start** presses the main button, and its **B** goes back; **A** with the cursor on another button presses that one, and held on a pile dot it still drags. In a round, none of these does anything, since only a press at a place may touch the score. On the title, Escape still quits a desktop game and Android's Back still leaves the app. The rules are unchanged: `Game` still starts or goes on with any press it hears, and the Show only decides which presses it passes on (`Show#primary`, `#play`, `#continue_on`).

No two buttons' reaches share a point any more. The maintainer's Android playtest found a tap on the lower half of the Dot size control's Standard opening "Your records" below it, because the two reaches, each a dot's width tall, overlapped, and the first in the list won. Now `Control.apart` splits any overlap halfway across the gap between the two buttons as drawn, a press on a shared edge goes to the nearer button (`Show#control_at`), and on an upright phone the Dot size row stands further above the buttons, up to a standard dot's width less a button's height, or 5% of the screen's height on a short one. `ScreenPlansTest` checks over fifteen window sizes, a 412 × 832 Android phone and an iPhone 13 mini both ways among them, that on the title, Game Over, and the Records screen no two reaches overlap, that a press at each button's middle reaches it, and that no two buttons overlap. The Game Over backing now ends above the buttons, which need none, so it hides less of the pile.

**Why:** Lee and Wickens (*Designing for People*) put error prevention before error recovery: a tap meant for the pile, or for a dot in the last instant of a round, should not leave Game Over, and on a phone, where the screen is crowded and the thumb imprecise, the maintainer felt the tap-anywhere screens were cluttered. Saffer (*Microinteractions*) asks for a visible trigger: a button says what will happen and where, and "anywhere" says neither. Tidwell (*Designing Interfaces*) gives each screen one prominent primary action, sized and coloured above the rest. And Schell's lens of the toy, which made the Game Over pile something to play with, needs the pile to be free: once only Continue goes on, every other press on Game Over belongs to the pile.

**To reverse:** In `Show#tap`, send `nil` on the title and Game Over to `game.press` again and on the Records screen to `close_records`, and draw the prompts as text again in `TitlePainter`, `FinalePainter` and `RecordsPainter`, with the words in `Look::WORDS`.

### Records are cleared by a held press, and undone, not confirmed

The Records screen has a quiet **Clear my records…** in its bottom right corner, on a row of its own under the prompt to go back, across from the title's **Your records** where the player's finger just was. It clears only once held for two seconds (`RECORDS_CLEAR` in look.rb), with a bar filling under it and the prompt replaced by what will go; letting go sooner changes nothing, and a press let go too soon leaves "Press and hold to clear…" for a moment. A gamepad holds **Y**, or **A** with the cursor on it, and the words name the button held. Clearing offers **Undo** in the same corner for ten seconds; a round, or the window losing focus during a hold, ends the offer or the hold.

**Why:** Lidwell's forgiveness: an undo serves the player better than a confirmation dialog they learn to dismiss, and a held press is hard to make by accident yet the same with a finger, a mouse, or a gamepad. The control is small and soft-coloured because records aren't the point of the game (Ferrara), and it sits far from where "Tap anywhere to go back" is aimed (Fitts). Its press never counts as going back. A round ends the offer because undoing after it would lose that round.

**To reverse:** Drop the corner control and `RecordKeeper`; nothing else depends on them.

### Clearing copies the records to one timestamped backup

`RecordKeeper` copies `best_score.txt` and `lifetime.txt` exactly to `best_score-<stamp>.txt` and `lifetime-<stamp>.txt`, notes them in `cleared.txt`, and only then empties the two files. The next clearing removes the copies the note names (and only names shaped like backups). Undo restores the exact text kept in memory; the backup stays on disk for support. The playtest log, `sound.txt`, `dot_size.txt`, `taught.txt` and `tilt_hint.txt` aren't records and are never touched.

**Why:** Lota's save folder can't rename, so, as the playtest log's archive does, the copy is written before anything is lost. One backup keeps the folder tidy while leaving a way back after Undo is gone.

**To reverse:** Keep every backup by not removing the noted ones, or none by skipping `back_up`.

### After clearing, the title is a new player's except for its buttons

With no rounds in the records, the title shows no best and no daily goal, as for a new player. It still offers **Your records** and the dot-size choice, because `cleared.txt` shows this player has played: the dot-size choice is a setting, not a record, and hiding it would leave a chosen size unchangeable until the next round; **Your records** leads back to Undo while it lasts.

**Why:** The player asked for their records to go, not for the game to forget them as a player.

**To reverse:** Make `Show#records_offered?` only `played?`.

## Controllers

### Gamepad support was written before Lota could report controllers

When gamepad support was written, Lota's development branch bound `Lota::Joystick` and LÖVE's gamepad callbacks, but the game was locked to Lota 0.1.2, which had neither. So `main.rb` defines `gamepadpressed`, `gamepadaxis`, `joystickadded`, and `joystickremoved`, which Lota 0.1.2 never called. The game now uses Lota 0.1.3, which calls them, so controllers work. `Shell::Gamepads` keeps the controllers that `joystickadded` hands it and reads only those. It never asks Lota for the list of joysticks each frame: doing so on Lota's development branch created new joystick objects that could be freed while still in use, and on iOS, where SDL presents the accelerometer as a joystick, that crashed the game. For a while phones and tablets took no controllers at all, but now that the game no longer asks for the list, and Lota has fixed the cause, a controller paired with an iPad is accepted too. `Shell::Gamepads` keeps only joysticks that are gamepads, so an iPad's accelerometer, which SDL also presents as a joystick, is never one.

**Why:** Writing the support early meant that moving the Gemfile to Lota 0.1.3 was the whole upgrade, and it was.

**Not yet checked:** Nothing has run with a real controller, nor with the virtual joystick in Lota's development build, because the test build available that night predated the joystick bindings.

**To reverse:** Remove the four gamepad callbacks from `main.rb`.

### A controller aims a cursor and presses where it points, like a click

**A** presses at the cursor's position, on the frame the button goes down, through the same path a mouse press takes (`InputRouter#gamepad_pressed`, then `Show#tap`). So the mute and Copy my result buttons, the title-screen pop, and the choice of which dot a press reaches all work exactly as they do for a mouse. The right trigger acts as a second **A**. It presses once when pulled past halfway, and can press again only after it has been released below 0.3, so a trigger resting near the halfway point can't press twice.

**Why:** One path for every kind of press means every rule about presses holds for a controller without extra code.

**To reverse:** The thresholds are `trigger_press` and `trigger_release` in `GAMEPAD` in `look.rb`.

### There is no aim assist

The cursor goes only where the stick sends it. It doesn't drift toward nearby dots.

**Why:** A "magnetic" cursor would choose which dot a press reaches, and the whole game is about the player making that choice, too soon or not. A cursor pulled toward the fresh dot would remove the stacking risk, and one pulled toward any dot would cause wrong taps the player never aimed.

**To reverse:** This would be a new feature in `Presentation::GamepadCursor`.

### The cursor moves fast at full tilt and slowly at a small one

The stick has a circular dead zone of 0.2, because worn sticks can drift up to about 0.15 when left alone. Beyond the dead zone, the cursor's speed is the square of the push (`GAMEPAD` in `look.rb`). At half tilt it moves at a quarter of the top speed, for fine aiming. The top speed is set by the window, not by the dot's radius: at full tilt the cursor crosses the window's diagonal in one second, ramp included. In a small window, the speed never drops below 16 R per second. That floor is the speed the cursor had before, which still crosses the 24 R desktop window in 1.5 seconds. (See "The gamepad cursor's speed follows the window" below.) A diagonal on the d-pad moves no faster than a straight direction.

The stick is read every frame, rather than through axis-change events, so that a change of window focus can't leave the cursor stuck moving. When several gamepads are connected, their pushes add together.

**Why:** A player needs to cross the screen quickly and also to settle precisely on a dot.

**To reverse:** Adjust `dead_zone`, `curve`, `speed`, `crossing`, and `ramp` in `GAMEPAD`.

### The cursor appears only for a controller

Any gamepad button, or a push on the stick beyond the dead zone, shows the cursor. Moving the mouse, clicking, or touching the screen hides it. While hidden, it waits where the mouse is, so a player who picks up the controller starts from there. Pressing **A** while the cursor is hidden still presses where it is waiting.

The cursor is a thin cream ring with four short ticks and a dot in the centre, each with a dark edge so it shows on any background. It is open in the middle so it never hides the dot it is over, and it is drawn on top of everything, aligned to whole pixels.

**Why:** A mouse player doesn't need a second pointer on screen. Making the first **A** press only reveal the cursor would mean the game ignored a press, which feels broken.

**To reverse:** Remove the `hide` calls in `Shell::App`'s mouse and touch handlers.

### Start, Y, X, and B are shortcuts on the menus, never during play

On the title screen, **Start** starts an ordinary round (without popping a title dot). On the Game Over screen, it continues, after the same pause as a tap. During a round it does nothing, because only a press at a position may affect the score. **Y** copies the result on the Game Over screen, as the Copy my result button does, and does nothing elsewhere. **Back** turns sound on or off, as **M** does.

**Why:** A button that scored without aiming would bypass the game.

The Records screen added three more. **X** opens it from the title, once it is offered, so a controller player needn't steer the cursor to the corner. **B**, the usual "go back" button, leaves it, and so does **Start**, which on every other menu screen means "go on". **A** with the cursor on no button presses Back, the screen's main button (since the dedicated buttons, A aimed at no button presses Play, Continue, or Back, and B also goes on from Game Over). **Back** stays the sound toggle on every screen, including this one, so one button never means two things. B and X do nothing during a round, for the same reason Start doesn't. Either shoulder button switches the title's dot-size choice once it is offered, because shoulder buttons usually switch between options, and both were free.

**To reverse:** The button mapping is in `Presentation::GamepadButtons`.

## Code

### The rules are type-checked by Steep, strictly

`sig/dot_popper/` holds an RBS type signature for every class in `lib/dot_popper/*.rb`, with no `untyped` escape hatches. Running `bundle exec rake` runs the tests and then Steep with its strict settings, so a call that Steep can't check fails the build instead of passing silently. `bundle exec rake test` alone doesn't need Steep, so a machine without it can still run the tests. Steep's gems are cached in `vendor/cache` for all three platforms, like the other gems.

Two changes to the code came from what the checker found. A `Field` now stores its width, height, and radius as floats, as a `Dot` already did, because an integer radius could leak into a dot's position through `Dot#confine`. And `Game#subscribe` called with neither a listener nor a block now raises at once, instead of failing later on the next event. RBS's built-in signatures leave out `Data#initialize`, so `sig/core/data.rbs` declares it, which lets a value class's own `initialize` call `super` with keywords.

**Why:** The rules are the part of the game where a silent mistake would matter most.

**To reverse:** Change the default task in the `Rakefile` to `test` alone.

### The simulator runs each device in its own Ractor

Ractors are Ruby's units of parallel execution, and they can share only deeply frozen (fully immutable) objects. The rules' values (fields, dots, stacks, clocks, and tap events) are all deeply frozen, so each Ractor can read the device list and the rule numbers without copying them. Each Ractor makes its own random number generator, seeded exactly as the one-at-a-time run was, so it plays the same rounds, and the script checks that the results match. `DotSize` was the one value that couldn't be shared, because its reason was a string built at run time. It is now frozen, and a test checks that every value can be shared.

**Why:** It makes the simulator faster on a machine with many cores, and shows off a modern Ruby feature.

Every device now plays once with each choice of dot size, so the script starts twelve Ractors; `DotSizing` and `SizeClass` freeze their names for the same reason `DotSize` freezes its reason.

**To reverse:** Run the devices in a plain loop in `script/simulate.rb`.

### The simulator starts Ruby with a larger heap, so its Ractors run in parallel

In Ruby 4.0, every garbage collection pauses all Ractors, and the simulation creates a lot of short-lived objects: new dots and a new stack at every step. With Ruby's default heap size, 10 rounds per device caused about 1,100 garbage collections, and the Ractors ran no faster than running the devices one after another (between 0.7 and 1.2 times as fast, over several runs).

So the script restarts itself with the `RUBY_GC_HEAP_*_INIT_SLOTS` settings that give each of the three smallest size pools a million slots, about 250 MB in all. With that heap, the same run causes about 25 collections. On the maintainer's Mac, whose ten cores were mostly busy with other work, 60 rounds per device took 28.9 seconds one after another and 14.5 seconds in Ractors, twice as fast. Other runs that night ranged from 1.2 to 2.2 times as fast as the other work came and went. Most of the remaining time goes to the 6K monitor, whose rounds alone are nearly a third of all the simulated time.

**Why:** Without it, the Ractors spent their time waiting for one another and gave no speedup.

**To reverse:** Remove the `exec` line near the top of `script/simulate.rb`.

### The typed rules use `if` and `is_a?` where pattern matching would read better

`Round#tap_at` would read well as pattern matching, `case dots.top_at(x, y) in nil ... in Dot(popped: false) ...`. But Steep 2.1 doesn't check `case`/`in` at all. It reports it as unsupported, at a level that is silent by default, and treats everything inside as untyped: a deliberate type error inside such a branch passed the check. So the `Steepfile` makes unsupported syntax an error, and the rules' branching stays in forms Steep can narrow. For example, after `if state.is_a?(Playing)`, Steep knows `state.round` exists.

Pattern matching is still used where nothing is type-checked: the fuzz test matches on each tap's event, and `script/simulate.rb` branches on the events and reports each round as a `Data` value instead of a hash.

**Why:** Code that the type checker skips is code nobody checks.

**To reverse:** Once Steep supports pattern matching, rewrite the branches and remove the `UnsupportedSyntax` line from the `Steepfile`.

### A seeded fuzz test checks the rules' invariants

`test/rules_fuzz_test.rb` plays 2,000 rounds on random fields, ranging from a sliver narrower than one dot to a large monitor. Each round is a random sequence of taps and clock ticks. Most taps are aimed at or near a dot, so overlaps are common, and some ticks are 20 seconds long. After every step, the test checks that:

- every dot stays inside the field;
- the score never goes below zero, and changes only by +1 or by the penalty the zero floor allows;
- the clock never goes negative, and changes only as the rules say;
- exactly one dot is fresh while the round is running;
- a tap reaches the topmost dot under it and changes no other dot;
- older dots stay above newer ones;
- every new dot offers a touch target within a second of spawning, or used every try to (see "A new dot is never hidden for its whole first second").

A second test drives the whole `Game` through its screens and checks that nothing outside a running round touches the score or the clock. The fuzz test needs no extra gem and runs in under a second. When it fails, it prints its seed, and setting `RULES_FUZZ_SEED` to that seed replays the failure. Deliberately reversing `Stack#top_at` or `Stack#slide_under` makes it fail at once.

**Why:** Hand-written tests cover the cases someone thought of; random play finds the ones nobody did.

**To reverse:** Delete the test file.

### doc/why_ruby.md argues for Ruby with this game's code, and gives Lua its due

[Why Ruby](why_ruby.md) puts each claim beside the code in this game that demonstrates it, and beside the idiomatic LÖVE Lua it replaces. Its numbers were measured that night on the maintainer's Mac. Moving thirty dots 100,000 times took 4.4 seconds in Ruby (3.4 seconds with YJIT, Ruby's just-in-time compiler), 0.58 seconds in Lua 5.4, and 0.012 seconds in LuaJIT, all ending with identical dot positions.

**Why:** A showcase for Ruby is more convincing when it is honest about where Lua is faster.

**To reverse:** Not applicable; it is a document.

### The Game Over pile is a toy that tilts and shakes

At Game Over, tilting a phone or tablet turns the pile's gravity toward the lowest side of the screen, and a sharp shake throws every dot up, against the pull. With a gamepad, the right stick turns it instead: the dots fall the way it points, and straight down when it is let go. While the pile is tilted, a lid along the top of the window keeps the dots on the screen. The accelerometer is switched on only while the pile exists. A light line under "Tap to continue" says how to do it on the first three Game Overs: "Tilt your iPad to roll the dots.", or "Push the right stick to roll the dots." with a controller (since removed; see "Game Over leaves the pile to be found by touch"). With no accelerometer and no controller, the pile is unchanged.

The math lives in `presentation/tilt.rb` and is tested. SDL reports the accelerometer in the device's own portrait axes, as the push holding the device up, and never turns those axes with the screen, so the game maps each of the four display orientations itself. The reading is smoothed with a time constant of 0.2 seconds, so a hand's tremor never reaches the dots. One g is the pile's existing gravity, so holding the device upright drops the dots exactly as before. A shake is a jump of more than 0.5 g away from the last 0.3 seconds' average, followed by a 0.6-second cooldown (first 1.2 g, then 0.8 g after the first iPad playtest). With `DOT_POPPER_CALM=1`, the pull changes four times as slowly and a shake never throws anything. `DOT_POPPER_FAKE_TILT=x,y` stands in for an accelerometer during testing.

**Why:** Jesse Schell's lens of the toy asks whether something is fun to play with even when there is no goal. Once the round ends, its dots no longer affect anything, which makes them a free toy, and handling the device is the most natural way to play with them. Players linger and play with the dots after the game, instead of leaving the moment the score appears. Since the rules are frozen by then, none of this can touch fairness.

**Later, after the iPhone playtest:** the maintainer found a shake tossed the dots "maybe a bit, not as much/'violent' as I'd expect". A shake now throws every ball at 20 radii a second, plus 40 for each g past the threshold, up to 108 (it was 24 for each g past it, up to 36, so a 1 g jolt threw at under 5). Each ball takes 0.6 to all of that, so the gentlest toss, 12 radii a second, is twice a dot's fastest speed. And it is seen to land: a bright cream ring bursts from every dot (`Look::SHAKE_RING`), the score rattles (`Look::SHAKE_RATTLE`), and a low tick sounds (`Show#shaken`, which `Tilting` calls). Juicing a response with more than one channel makes a small action feel big (Swink, *Game Feel*); it is Game Over, so nothing it covers matters to a score.

**To reverse:** In `Shell::App#load`, stop creating and subscribing `Tilting`, and stop passing it to the `Renderer`. The pile then falls straight down. Deleting `presentation/tilt.rb`, `shell/tilting.rb`, and `shell/accelerometer.rb`, along with `Look::TILT`, removes the feature entirely.

### The stacking rule is taught on Game Over, not in play

*Later: the note's words are gone, and Game Over replays the wrong tap on the pile instead (see "Game Over teaches the stacking rule by replaying the wrong tap").*

The hint that explains the stacking rule no longer appears during a round. It appears on Game Over instead, after a round in which the player tapped a popped dot while the bright dot was hidden underneath it. It shows on the first two such Game Overs and never again. The note is two short lines between the score pill and "Time's up!", which moves down a little to make room: "New dots appear under the popped ones. Wait for the bright dot to slide out, then tap it." On a narrow screen, a line that would not fit is broken evenly. `taught.txt` now counts how many times the note has shown. A player whose file says `taught`, from an older version, already saw the hint, so it does not show again. In play, the dashed outline of the hidden bright dot is unchanged.

**Why:** Players don't read during intense action (Johnson, Hodent), so a sentence that appeared mid-round mostly went unread and covered the field. A penalty is also the wrong trigger for reading (Saffer). Game Over is calm, and it follows the mistake closely enough that the note still makes sense. Showing it only after a mistake caused by a hidden dot means it explains something the player just saw. Showing it twice gives a player who taps through quickly a second chance.

**To reverse:** Pass `lesson: nil` to the `Finale` in `Show#round_ended`. Setting `Look::LESSON.times` changes how often the note shows.

### The first Play opens a tutorial with no words

On a fresh install, the first Play opens a tutorial of about 20 seconds: the first round's opening, before its clock runs. It has four beats. A bright dot drifts, time eases to a stop in 0.15 s, a spotlight dims everything else, and the tutorial's guide taps the dot over and over until the player does. The pop bursts from the dot while it still looks bright and holds time still at that instant, while "+1" flies out of it into the HUD's score and a small stopwatch with "+1" into its time, each counting up as it lands, with a chime and a tick. As time flows again, the dot takes its popped look and a new bright dot is born under it (see "The tutorial's reward comes out of the bright dot"). As it peeks out, time stops again, and the guide taps the popped dot once, showing what that costs (see "The tutorial's guide shows a wrong tap's cost, with no ✕"). The guide then waits to one side while time flows slowly until the bright dot is clear, and moves to it and taps. A tap of the player's on the popped dot costs the same, and the beat goes on (see "Every wrong tap in the tutorial costs what it does in play"). The last pop bursts, still bright, its numbers fly in, and as the light moves to the clock it spawns a new bright dot under both, as any pop does, and the round goes on from there (see "The tutorial hands its dots, score and time to the first round"). The guide is the player's own hand: the pointing-hand emoji (see "The tutorial's touch guide is the pointing-hand emoji"), a mouse pointer, or a gamepad's reticle with its A button. A ⏭ button in the top right corner, Escape, and a gamepad's B skip it, and start a fresh round at once. It never shakes the screen, and muted it teaches as fully, since every lesson is drawn.

**Why:** How to play must never depend on reading. In playtests, one player ignored the title's words and asked how to play, and another never noticed that pops add a second. The maintainer's goal is that "a person who can't read English should understand and enjoy it", so the tutorial uses only numbers, the clock's digits, and drawn shapes. It stops time so the player can look at the one thing that matters, and it uses the real dot drawing, the slowest real speed, the real HUD and the real pop and penalty effects, so what it teaches is what the game does. Each step on is the player's own tap, so they learn by doing, and a wrong tap is safe.

**To reverse:** Construct `Show` without `tutorial_flag:` in `Shell::App#load`.

### The tutorial is a scene of its own, not a round

*Replaced: the tutorial is now the first round's opening, and the round goes on from it (see "The tutorial hands its dots, score and time to the first round").*

`Presentation::Tutorial` was a scripted scene the Show played over the title. When it ended, its dots faded, its HUD went back to 0 and 10, and the Show started a fresh round, as Play does, so nothing in it was scored, logged, or counted.

**Why:** It read the rule "nothing touches the score or clock outside Playing" as forbidding any carry-over. The maintainer found that its ending taught something that never happens in the game: two dots fade away, a new one appears, and the HUD drops from 2 and 12 to 0 and 10.

**To reverse:** See the entry that replaced it.

### The tutorial's flag survives clearing the records

`tutorial.txt` in the save folder says `seen` once the tutorial opens, and it is kept apart from the records, as `taught.txt` is. Clearing the records leaves it. `DOT_POPPER_TUTORIAL=1` opens it on every Play, to try it; the bot, the GUI director and `DOT_POPPER_NO_TUTORIAL=1` leave it out.

**Why:** Clearing the records starts the scores over, not the player. Someone who has played doesn't need to be shown how again.

**To reverse:** Have `RecordKeeper` remove `tutorial.txt` when it clears.

### Players from 0.9 skip the tutorial

The tutorial is due only for a player who has not played: no round in `lifetime.txt`, and records never cleared.

**Why:** Everyone with a 0.9 save has already played, so the tutorial would only stand between them and the game they know.

**To reverse:** Pass `played: false` to `TutorialFlag#due?` in `Show#play`.

### The dot-size choice is a labelled segmented control

The title's dot-size choice used to be a single pill that read "Dots: same size everywhere" and switched when tapped. It is now a small control labelled "Dot size", with two segments side by side, one for each choice (now named by what they do on this screen; see "The dot-size choice says what it does on this screen"). The chosen segment is filled in cream with dark text. Tapping a segment chooses it, and tapping the chosen one again changes nothing. Either shoulder button on a controller still switches between the two. On a wide window the control sits in the bottom row between "Your records" and the mute button, with its label on the left and its segments centred on the screen. On an upright phone it takes a row of its own above them, with the label above the segments. Each segment is a button's height (at least 44 units), and a tap reaches it within a dot's width, as for the other title buttons.

**Why:** A toggle should show its options and which one is chosen (Tidwell). A single pill showed only the current state, so it didn't say that tapping it would switch, or what the other choice was. Naming the choice "Dot size" and each option by what it does makes the control read as a setting rather than a statement (Podmajersky).

**To reverse:** In `TitlePainter#draw`, draw a `PillButton` at `layout.sizing_control.frame` instead of the `SegmentedPainter`, and have `Show#tap` call `toggle_sizing` on that frame's reach.

### The Records screen keeps labels near their numbers

The rows' type is a little larger (23 units at a layout scale of 1, up from 20). Each column is only as wide as its longest row needs, measured at that size, so the columns no longer stretch to fill a wide window. Two columns stand side by side only when both fit at that width; otherwise everything stacks in one centred column. A faint dotted leader runs from each label to its number. The two dense sentences under the heading are now one short line, "This screen is about 12 dots wide and 8 dots tall." With dots sized to the screen, a second line follows: "Dots are sized to fit this screen, so scores compare across devices."

**Why:** Proximity groups things (Johnson, Tidwell). On a wide window, the old columns put a label like "Best score" half the screen away from its number, so the eye could lose the row. The second sentence explained a setting from a screen where it can't be changed. Now the title's segmented control names both choices, so Records only needs to say what the current choice means.

**To reverse:** Pass `widest: nil` to `RecordsLayout` in `RecordsPainter#draw`, drop `leader`, and restore `Look::RECORDS.text` to 20.

### Game Over's words sit on a soft backing

From "Time's up!" down to "Tap to continue", Game Over's words sit on a dark, rounded backing in the night's deepest ink. It is 60% opaque in the middle, and its edges fade out over 40 units in ten layers, so the pile shows through it and around it. It is as wide as the widest line in the block, and it fades in with the heading. `Presentation::ScrimLook` holds the settings, and `Look::FINALE_BACKING` sets them for Game Over.

**Why:** Figure and ground. Once the pile settled behind the summary line and the share button, light dots ran through the text and made it harder to read. A darker ground behind only the text keeps it readable. The pile is the toy, so the backing must never hide it: at 60%, with feathered edges, the dots stay visible.

**To reverse:** Remove the `backing` call from `FinalePainter#draw`.

### The title reads more clearly

Three changes. At its faintest, "Tap anywhere to play" now breathes down to 80% opacity rather than 50%, so it stays easy to read at every point in its cycle. The legend's base size is 29 rather than 24. It still scales with the layout and shrinks by whole sizes until it fits, so wide windows get larger legend type and narrow screens are unchanged. Finally, the title's words, from its name to its prompt, sit on a faint feathered backing at 40%, and the veil over the whole title is slightly darker (76%, up from 72%). Together these dim the drifting dots most where they pass behind the text.

**Why:** At half opacity the prompt nearly disappeared over a passing dot, at the moment a new player looks for what to do. The legend teaches the scoring, but on a wide window it was small next to the name. The drifting dots are scenery and shouldn't compete with the words.

**To reverse:** Set `Look::TITLE.faintest` to 0.5, `dim` to 0.72, and `TYPE.legend` to 24, and remove the `backing` call from `TitlePainter#draw`.

### The HUD is lighter, and a wrong tap's edge glow is softer

The HUD's pill is a little smaller, with 35-unit numbers (down from 40) and less padding, and only 40% opaque (down from 62%). A dot that drifts under it stays visible. Its numbers and labels are drawn with the same soft dark outline as the floating numbers, so they stay crisp over a bright dot. A wrong tap's edge glow peaks at 42% (down from 60%), reaches in a tenth of the screen's shorter side (down from 16%), and fades in 0.32 seconds (down from 0.42). `FlashLook` now carries the band's width, so each glow sets its own.

**Why:** The HUD sits over the field, and the field is what the player is watching. An opaque pill hid dots that a tap could still reach. The edge glow tinted dots near the edges pink for almost half a second, which made it harder to tell which ones were fresh just when the player was trying to recover from a mistake.

**To reverse:** Restore `Look::HUD.backing` to 0.62 and `TYPE.hud_number` to 40, draw the readouts with `pen.text`, and set `PENALTY_FLASH` back to `alpha: 0.6, duration: 0.42, band: 0.16`.

### The dot-size choice says what it does on this screen

The title's "Dot size" control no longer names its options from a designer's view of many devices. The first segment is **Standard**, the spec's size. The second is named by what sizing the dots to the screen does here: **Smaller, more room** where the fitted dot is more than a tenth smaller than the standard one (a phone), and **Bigger, less room** where it is more than a tenth bigger (a big monitor). Each segment starts with a small fresh dot, the standard one about a third of the segment's height across and the other in true proportion to it, kept between half and 2.2 times as big so both stay legible. The title's drifting dots already take the chosen size, so choosing shows its effect at once. Where the two sizes are within a tenth of each other, as in the 24 × 16 R window, the control is left out: its taps and the shoulder buttons do nothing, the saved choice is kept, and rounds still follow it (within a tenth, it makes no visible difference). Everything is worked out again from the window's size whenever it is asked, so a resized window brings the control back or takes it away. `Presentation::SizingPreview` holds the comparison, `Look::SIZING` the numbers, and the words are in `Look::WORDS`. The Records screen keeps the reason for the choice, in one line, when dots are sized to the screen: "Dots are sized to fit this screen, so scores compare across devices." In the code, `DotSizing::SAME_EVERYWHERE` is now `DotSizing::STANDARD`; `dot_size.txt` still says "same" or "fitted", so old saves keep working. With autoplay, the bot taps the other choice the first time the title shows it, so a development run shows the dots change.

**Why:** "Same everywhere" and "Fit the screen" only make sense to someone comparing devices, which most players never do (Pinker's curse of knowledge). A player sees one screen, so the labels say what happens on it (Podmajersky), and the dot icons preview each option before it is chosen (Tidwell's Preview pattern; Saffer's "bring the data forward"). A choice that changes nothing visible is noise, so it is hidden until it matters, and the cross-device reason moves to the Records screen, where scores are compared (Lidwell's progressive disclosure).

**To reverse:** Have `Show#sizing_offered?` return `records_offered?`, and name the segments with fixed words again in `Words#sizing`.

**Later:** With fitted dots the default ("Dots fit the screen unless the player chooses Standard"), the first segment is **Fit the screen** and the second **Standard**, and each says what it does here in a second line (`Words#sizing_note`).

### A fresh dot's edge is its hit circle

A fresh dot at rest now ends exactly at radius R, where its hit circle ends, in a thin bright cream rim (`palette.fresh_rim`, 0.055 R wide and never under a pixel and a half) whose outer edge is smoothed over one device pixel. The halo is a faint lip about 0.035 R deep at 16%, down from a cloud reaching 1.6 R at 34%. Every dot's shadow is smaller and lighter (a disc 1.08 R across dropped 0.07 R, at 40%), so a popped dot's opaque body visibly ends at R too. The plain-shapes fallback draws the same rim, and its shadow is only a crescent below. The idle "breathing" swell of fresh dots is gone; spawn, pop, and wrong-tap motions still scale a dot briefly. The bloom pass is off (`BLOOM.strength` 0), with its code left in place.

**Why:** After playing, the maintainer said the fuzzy glow made it hard to track where the clickable area was while everything moved. A target is acquired by its edge (Fitts's law, via Lidwell), and people track a moving target by what they perceive as its boundary (Johnson; Hodent), so the visible edge has to be the clickable edge. Swink's rule of clarity before polish applies. The halo reached 60% past the hit circle, and breathing moved the edge by about 2%. The bloom blurred the whole bright disc. Any bloom strong enough to see spreads several pixels past R, and one tight enough to stay inside the rim adds nothing, so it is off. Fill, gloss, and rim keep the fresh dot the brightest thing on screen. Fresh and popped still differ by lightness, and a popped dot is still never drawn inside its hit circle. `LookTest` checks that the halo has faded to nothing by 1.15 R, that the shadow stays within 1.16 R, and that bloom is off. `DotAnimationsTest` checks that a fresh dot at rest is drawn at exactly scale 1.

**To reverse:** In `Look::DOT`, set `rim: 0`, `halo_width: 0.3`, `halo_alpha: 0.34`, `extent: 1.6`, `shadow_reach: 1.25`, `shadow_offset: 0.11`, and `shadow_alpha: 0.55`, and set `BLOOM.strength` to 0.7. Breathing was a `Breathe` term in `DotAnimations#pose`; restore it from the commit before this one.

### The Game Over pile can be dragged and thrown

On Game Over, a press on one of the pile's dots that wanders more than a quarter of a radius, or stays down for 0.15 seconds, picks the dot up. It follows the pointer, pushing the others aside, and when let go it flies off at the pointer's speed over its last tenth of a second, at most 40 radii a second (6 when calm). Each finger holds a dot of its own, and a dot already held can't be taken by another finger. A press that stays still and lets go quickly is a click, on a dot or not, and goes back to the title as a press used to, but only as it is let go. A press off the pile goes on however long it is held, so a slow tap still works, but a swipe there does nothing, and no click goes on while another finger is dragging. A press made during the grace period is ignored when it lets go, exactly as it was ignored on press. "Copy my result" still acts on press, and so does every press during a round. A grab is dropped when its touch id is pressed again (iOS can cancel a touch without saying so), when the window loses focus, and when the pile goes. Dragging closes the pile's lid, as tilting does, and a held dot is a Box2D bullet so it can't pass through a wall. `Presentation::PileGrabs` decides all of this without Lota; `Shell::Dragging` carries it out on the `Pile`. The hint under **Tap to continue** now says "Drag the dots to play with them." on a computer, "Drag the dots, or tilt your iPad to roll them." on a phone or tablet, and still names the right stick when a controller is connected.

Lota 0.1.3 binds `MouseJoint.new` but none of its setters (no `setTarget`, no `setMaxForce`), so a joint can't follow a pointer. A held dot is instead given, each frame, the velocity that closes on the pointer in about 0.05 seconds, capped at 60 radii a second. Box2D's contacts and walls still stop it, as they would stop a joint's pull.

**Why:** Schell's Lens of the Toy. The pile was the one thing on Game Over a player could play with, but only by tilting a tablet or pushing a stick. Most players have only a finger or a mouse, and reaching out to grab a dot is the first thing they try. Acting on release at Game Over costs nothing, since the round is over and nothing is timed, and it means the press that starts a drag can't throw the player back to the title.

**To reverse:** In `App#press`, call `tap` for every press, and remove `Dragging` from `App#load`.

### A group's first round is never a new best

The first round ever played in a size class (standard dots on a small, medium, or large screen, or dots sized to the screen) sets that class's best but is not called a new best. Game Over shows the ordinary best line, "Your best: 18", with no "New best!", no celebration, and no fanfare, and the shared result doesn't claim a new best or a tie. No "New record" line appears on a class's first round either, as before. `BestScore#first?` says whether a class has a round yet: a class's first round is now saved even when it scores 0, and `Events::RoundEnded#first` carries the answer to the Finale. A class whose rounds were all 0 before this change reads as having none, so its next round counts as its first.

**Why:** Juul and Hodent on fair feedback, and Podmajersky on making every line do a job. A first round in a new class beat nothing, so praising it is praise the player didn't earn, and it cheapens the next real "New best!". The maintainer chose the plain best line over a special first-round message: it is true, and it sets the target for next time. Which class the bests belong to is explained on the Records screen.

**To reverse:** Have `BestScore#record` return `true` on a class's first round, and drop the `first:` arguments from `Words#short_of_best` and `#share_text`.

### The Records chart dims rounds from other groups

Each of the last 20 scores now keeps the size class it was played in (`LifetimeStats#recent_classes`, saved as `recent_classes=?,medium,fitted`). On the Records screen's chart, a bar from a round outside the class whose bests are shown is drawn at 30% and is never marked or labelled as the best. It keeps its true height, so every bar shares one scale. When any bar is dimmed, a line under the chart says "Brighter bars are rounds with standard dots on screens this size." (or "...with dots sized to the screen."). Scores saved before classes were kept count as unknown, and so are dimmed. The bests' heading now names the group in the same words, "Your bests with standard dots on screens this size", using the title's "Standard".

**Why:** Ferrara and Garfield on honest feedback. The chart sat next to bests that count only one class's rounds, yet it showed every round alike and could crown a bar from a phone, or from fitted dots, as the best. Dimming keeps the history visible while showing which rounds the bests actually compare.

**To reverse:** Pass `mine: [true] * scores.size` to `ScoreBars` in `RecordsPainter#chart`, and make `RecordsSheet.build` set `chart_note: nil`.

### The words name the press the player is making

*Later: the legend, the stacking lesson and the pile hint have no words now (see "The title's legend is the tutorial's signs, not sentences" and the entries after it). The buttons still name a gamepad's, and the tutorial's guide is drawn as the hand in use.*

Every line that says what to do follows the input the player used last (`Presentation::InputKind`, which `Show#input=` sets from each `Tap` that `InputRouter` makes and from each gamepad button or stick push). With a finger the line says "Tap", with a mouse it says "Click", and with a gamepad it names the button: "Press A to play", "Press A to continue", and "Press B to go back". The title's legend says "Pop a bright dot" and "Hit a popped dot" with a gamepad, because "Press A on a bright dot" reads worse. The stacking lesson ends "then pop it". Game Over's hint says "Hold A on a dot to drag it, or push the right stick to roll them." Phones and tablets start out with touch, and computers start out with the mouse. `Words#for(kind)` gives the words for one kind of input. Each phrase that varies is a `ByInput`, so painters read `words.play` as before.

The words that count mistakes are now the same for every input: "2 mistakes" in the round's summary, the shared result, and the Records screen, and "without a mistake" in the daily goals. A total over a lifetime of rounds may mix taps and clicks, so it shouldn't name either.

**Why:** In a real-hardware playtest, the maintainer pointed out that "tap" is for touch screens and "click" is for a mouse. An instruction should name what the player is actually doing with their hands.

**To reverse:** Give every field of each `ByInput` in `WORDS` the same text.

### The gamepad cursor's speed follows the window

At full tilt, the cursor crosses the window's diagonal in one second (`crossing`), whatever the window's size. Its speed never drops below 16 R a second (`speed`). It gathers speed over 0.3 seconds (`ramp`): its pace may rise by at most 1/0.3 of the top speed each second, and only up to what the push asks for. So a gentle tilt is at its speed within a few frames, a full tilt takes 0.3 seconds to reach full speed, and letting go stops the cursor dead. The top speed counts half the ramp, so the whole crossing still takes one second.

**Why:** On a 4K TV at 200%, a speed fixed in dot radii felt far too slow when the window was maximized, though it felt right in a small window. Building up speed lets a full tilt cover the screen without making the first frames jumpy. Stopping at once keeps aiming precise.

**To reverse:** Set `crossing` very high to return to the fixed speed, and set `ramp` near zero to remove the build-up.

### A gamepad's A drags the Game Over pile as a mouse button does

The A button, or the right trigger, is a pointer at the cursor. It goes through the same `PileGrabs` as the mouse, under the key `:gamepad`. Each frame while it is held, the shell moves that pointer to the cursor. Holding A on a dot for 0.15 seconds, or moving the cursor past the slop, picks the dot up. The dot then follows the cursor at the same pace as it follows a mouse. Letting go throws it at the cursor's speed over the last tenth of a second. A quick press and release that drags nothing is a click, which continues as it is let go, after the same grace. Start still continues at once. Holding A and the trigger together counts as one press. `Lota.gamepadreleased` is new in `main.rb`.

**Why:** The maintainer found that dragging worked with the mouse but not with the controller.

**To reverse:** In `App#gamepad_down`, call `tap` directly, and drop `gamepad_released`.

### The title and Game Over stack their lines in the room they have

The title and Game Over no longer put each line at its own fraction of the screen's height. Each screen builds an ordered list of blocks (`Presentation::Block`: a measured height, the gap above it, its width, and a drop rank if it is optional), and a `Column` stacks them as one centred group in the room the screen has. On the title that room runs from the safe area's top margin to a margin above the bottom row ("Your records", the dot-size choice, and the mute button), which is laid out first. When the dot-size choice has its own row above the buttons, that row is reserved too. On Game Over the room runs from under the HUD to the safe area's bottom. When the blocks don't fit, the type shrinks by whole sizes, 5% at a time, down to 70% (never under 12 units, unless a line was already smaller). If they still don't fit, the least needed lines go, and the type grows back as far as what is left allows. On the title the streak goes first, then the goal, then the best, and last the name shrinks further. The legend and the prompt always stay. On Game Over the drag/tilt hint goes first, then the record, the summary, the goal, the best line, "Time's up!", the button, and last the lesson. The score and "Tap to continue" always stay. `TitleScreen#plan` and `FinaleScreen#plan` do this without Lota, measuring with `Shell::FontMeasure` in the game and `RoughMeasure` in tests. The Show keeps the plans, so "Copy my result", "Your records", the dot-size segments and the goal's twinkles take their places from the same plan the painters draw. Game Over's backing now wraps the whole group, the lesson and the hint included.

**Why:** On a 4K TV at 200%, the playtest found "You met today's goal!" drawn over "Time's up!" whenever the lesson moved the heading down, and a small window piled the title's lines on top of each other. Fixed fractions can't know which optional lines are showing. Tidwell's visual framework (one consistent column, with spacing that follows importance) and her advice to make repeated elements consistent call for one layout that every line goes through. `ScreenPlansTest` checks, across ten window sizes and every combination of optional lines, that no two blocks overlap, that nothing leaves the safe area or runs into the bottom row or the HUD, and that the required lines always stay.

**To reverse:** Restore `Layout#share_button`, `#finale_goal_y` and `#continue_y`, `LessonLook#room` and `TiltLook#hint_at`, and the painters' fixed fractions from the commit before this one.

### The GUI tests play the real game in real windows

`rake test:gui` starts the game with `bundle exec lota run`, as a developer does, once for each scripted session in `test/gui/scenarios/`, and `test/gui/scenarios_test.rb` checks that each one quit with status 0 after printing its checks. `main.rb` loads the director (`test/gui/director.rb`) only when `DOT_POPPER_SCENARIO` names a session, so a normal launch never runs it. The director puts a module in front of Lota's callbacks. Each frame's `update` gets the step the session asks for, a sixtieth of a second unless it waits longer, rather than the real time that passed, and frames spent waiting for the window system to resize the window or switch it to fullscreen pass no game time at all. Presses go onto Lota's own event queue with `Lota::Event.push`, so they reach `main.rb`'s callbacks on the next frame by the path a player's do. Resizes go through `Lota::Window.update_mode`, fullscreen through F11 and `Lota::Window.set_fullscreen`, and pixel checks read the drawn frame back with `Lota::Graphics.capture_screenshot`. The director also stands in for Lota's error screen, which would wait for a player, so an error anywhere exits with 1. Lota can't queue a `Joystick` yet, and its queue ends a message at the first `nil`, so a pushed gamepad press carries the number 0 in the pad's place. `main.rb` never asks which pad pressed. The gamepad's drag uses `DOT_POPPER_FAKE_GAMEPAD` and `DOT_POPPER_FAKE_DRAG`, because only a real stick moves the cursor. Every run uses a fixed seed, date (`DOT_POPPER_TODAY`) and window size (`DOT_POPPER_WINDOW`), so it plays the same dots on any machine. Each run gets its own save folder (`DOT_POPPER_SAVE_AS`), and `ALSOFT_DRIVERS=null` keeps it silent. Waits are counted in frames, never in seconds on the clock. CI runs the suite on Ubuntu under `xvfb-run` and Openbox, drawing with Mesa's llvmpipe, as Lota's own Linux CI runs its windowed tests. Locally it runs in the hidden macOS session, or on a screen nobody is using for about a minute.

**Why:** The unit suite never runs the shell that talks to Lota. A resize called a method that was never defined, reached `trunk`, and was caught only when someone ran the game in a window by hand. The Prism check in `test/shell/defined_calls_test.rb` now catches that kind of mistake. But only a running game catches a wrong argument to Lota, a callback that is never wired up, or a screen that fails to draw. There was no good reason to avoid windows: Xvfb gives CI a screen, and the hidden session gives the maintainer's Mac one. The maintainer asked that the suite be fast and reliable above all. Driving the clock instead of following real time keeps it deterministic, and each session finishes in a few seconds. Deckbuilder's `rake test:gui` also starts its real game as a separate process with settings in its environment. This suite does the same, but checks behaviour, not stills.

**To reverse:** Delete `test/gui/`, the `test:gui` task and its exclusion from `rake test` in the `Rakefile`, the last line of `main.rb`, `App`'s readers, `.github/workflows/gui.yml` and `script/with-openbox.sh`.

## Playtest kits

### Dot Popper builds its own apps and kits, with `lota fuse`

Every desktop app is built one way: `lota fuse`, with Lota 0.2.2's release gem for the platform from `vendor/cache`, checked against the release's `SHA256SUMS`, on that platform's own runner. The Package workflow builds the apps on every push to `trunk`, now for Linux x86_64 on `ubuntu-24.04` too, and the Kits workflow builds a playtest kit per device on `v*` tags and by hand. Neither runs `fledge build` for a desktop app any more.

**Why:** Lota's maintainer stopped building Dot Popper's kits, and the maintainer asked that Dot Popper build its own artifacts with Lota, using only released tools. `lota fuse` is Lota's documented way to share a game, and it did everything the Fledge build did, so there was no reason to keep a second way.

**To reverse:** Put `bundle exec fledge build` back in place of `.github/actions/fuse` in package.yml; `bin/dot_popper` and `fledge.yml`'s `programs:` entry are still there for it.

### One kit in, one results file out

Each kit is one archive, and the player returns one file. On Windows and Linux, a script (`playtest.ps1`, `playtest.sh`) asks the checks one at a time while the game runs and writes everything, system facts, answers, the game's output, and its saved files, into `dot-popper-results.txt` beside itself. The macOS and iPad kits carry a sheet to fill in, since a script can't start the iOS app, and the macOS README covers the frame-rate output and the save folder by hand.

**Why:** It is the maintainer's rule for kits: he reads one kit and sends back one file, never coordinating between them. A script on the desktops records what he would otherwise have to copy out by hand, such as the GPU driver and the frame rate.

**To reverse:** Ship the sheets alone; `script/playtest_kit.rb sheet` renders one for any device once `ResultsSheet::DEVICES` names it.

### The questions live in `playtest/checks.yml`

Every check's words are in one file, and a test checks that each one has wording and an answer on every system, and that each phrase a check quotes is one the game shows. The desktop list is shared by Windows, macOS, and Linux, with wording that differs only where the keys or tools do.

**Why:** Questions copied into four scripts and sheets would drift apart, and a question that names a button by a word the game no longer uses ("wrong tap" for "mistake") confuses the player it is meant to help.

**To reverse:** Write the questions into each template directly, and drop the test.

### The mute check restarts the game itself

Check 2 asks the player to mute and quit; the Windows and Linux scripts wait for the game to close and start it again before asking whether the mute held. When the game closes unexpectedly before a check, the script notes it and starts it again.

**Why:** The question is whether the mute survives a restart, and a script that starts the game anyway can make the restart a single step for the player. Each start is a separate session in the results, with its own output.

**To reverse:** Set `restart: false` on check 2 and tell the player to start the game again in its `try`.

### The iPad and iPhone kit follows Lota's phone guide, with Lota's iOS host

The iOS project is built by the iOS route of Lota's `doc/guide/phones.md` at its `v0.2.2` tag: a clone of Lota at the tag, SDL3 from Lota's `rake ios:sdl3`, Lota's gem built and unpacked into a folder that the phone project names as a path gem, the guide's phone project layout (the game in `game/dot_popper`, a `main.rb` that loads its `bin/dot_popper`, the hosts in `host/`), and Fledge v0.6.0's `fledge build ios`. The host is Lota's own, from the gem, with Dot Popper's `ios/host` over it holding only `Host/main.m`, which adds the night's ink behind SDL's view, `Host/Info.plist`, which adds the display name, and `Host/PrivacyInfo.xcprivacy`, the App Store's privacy manifest. Nothing comes from Lota's experiment branches. The project targets iPhone and iPad.

**Why:** Lota's maintainer allowed only released tools, and 0.2.2 is the first release whose guide documents the whole phone route and ships a host. Lota's host already sets the Ambient audio session and `SDL_ACCELEROMETER_AS_JOYSTICK=0`, the two things Dot Popper's own host was written for, and leaves the app's output on its own streams under Xcode, so keeping only the two files Dot Popper changes makes each Lota upgrade a matter of reading those two diffs. The guide says the hosts are the game's to change once copied, and Lota's host has no setting for the colour behind the game, so that stays in Dot Popper's `main.m`. (Before 0.2.2, the kit followed one line of Lota 0.1.3's CHANGELOG with a host of Dot Popper's own, from Fledge's `examples/sdl_phone`.)

**To reverse:** Drop the `ipad` and `ipad-simulator` jobs from kits.yml.

### The Android kit follows Lota's phone guide, at v0.2.2

The experimental Android kit is built by `.github/workflows/android.yml` by the Android route of Lota's `doc/guide/phones.md` at its `v0.2.2` tag: `rake android:deps` with NDK r30, which builds SDL3 with LÖVE's libraries, Lota's gem unpacked into a path gem's folder, the guide's phone project layout, Lota's Android host from the gem in `host/android`, OpenAL Soft's licence and source in `licenses/`, and Fledge v0.6.0's `fledge build android`. Dot Popper's `android/host` holds only the two files it changes over Lota's host: the manifest, which traps Back (below), and `MainActivity.java`, which adds the `lota.env.*` intent extras. The probe program `android/android_kit` is the phone project's `main.rb`. By hand, the workflow builds from another Lota tag or commit. The kit is a debug APK, a README, and `android-results.txt`, and the job also builds and signs the release App Bundle.

**Why:** Until 0.2.2, no Lota release built for Android, and the kit copied the recipe of Lota's spike at its unreleased commit `84c0eda`, with SDL3 from Fledge's `sdl_phone` script and a gem folder made by hand. Lota 0.2.2 releases and documents that route, so the kit takes the release, and what the release does itself (SDL's build and Java classes, the gem's folder) leaves the workflow. A debug build is the one Android installs without a signing key of the maintainer's own, and only a debuggable build takes `lota.env.*` intent extras, which the emulator checks use; Lota's host has no such way in, so it stays Dot Popper's addition.

**To reverse:** Delete `android.yml`, `android/`, `.github/android_emulator*.{rb,sh}`, the `android` list in `playtest/checks.yml`, and `playtest/README-android.txt`.

### The Android host traps Back

The manifest sets `SDL_ENV.SDL_ANDROID_TRAP_BACK_BUTTON`, as Lota's guide describes, and Lota's `MainActivity` registers an empty `OnBackInvokedCallback` on API 33 and newer when it is set, so Back reaches the game only as Escape. The emulator job checks that Back is ignored in a round and at Game Over and leaves the app from the title.

**Why:** Without the trap, SDL sends Escape and then lets Back through, and Android closes the app at once, so Back in a round would throw it away. Under predictive back, which an app targeting API 36 gets on Android 16, the system's own callback takes Back before SDL sees it, and the empty callback stands in its place. On Android 13, as on the Nord, the system ignores that callback without `android:enableOnBackInvokedCallback`, and SDL traps Back in `onBackPressed`.

**To reverse:** Remove the meta-data line from `android/host/src/main/AndroidManifest.xml`; Back then leaves the app from every screen.

### A mouse lights up the button under it

Every button the mouse is over (the title's "Your records", Dot size segments and speaker, Game Over's "Copy my result", and the Records screen's "Clear my records…" and Undo) brightens its backing and outline over an eighth of a second, and the pointer becomes the system's pointing hand. Both follow the same reaches the Show takes taps from (`Show#controls`), and only while the last press was the mouse's: a finger or a gamepad never hovers.

**Why:** The macOS playtest found no sign of what could be clicked. A mouse user reads affordances from hover (Tidwell); a touch player has no hover to read, and a lit button under a resting pointer would mislead a gamepad player. One list of reaches for taps and hover means a button never lights where a click would miss it.

**To reverse:** Drop `Show#hovered` and `App#point_the_mouse`, and the painters' `hover:` arguments.

### A tagged kit takes the tag's version; a release candidate its base

CI builds a tag as that tag's version, without its `v`, in place of `fledge.yml`'s, and the Kits workflow fails unless each kit's header names the tag and that version. A release candidate (`v0.8.2-rc.1`) builds its base version, 0.8.2, and its header says "Dot Popper v0.8.2-rc.1, …, version 0.8.2". A build by hand, or of a branch, keeps `fledge.yml`'s.

**Why:** The v0.8.2-rc.1 macOS kit said "version 0.8.1", since `fledge.yml` hadn't been bumped. The tag is what a release is. macOS's and iOS's `CFBundleShortVersionString` and Windows' file version take only numbers, so an rc's suffix has no form every platform allows, and the header's tag still tells one candidate from another. Kits.yml pins the version in CI's copy of `fledge.yml` because the shared fuse action reads it from there.

**To reverse:** Drop the "Take the version from the tag" steps and the `check-build` lines from kits.yml.

### Credits is a screen over Records, and finds its license texts by looking upward

Credits opens from a quiet pill beside Back on the Records screen (above Back on a phone too narrow for both), over Records rather than as a screen of its own: Back, Escape and B go back one step, to Records. It says who made the game, then Dot Popper's notice, its LICENSE and that the sounds and icon are CC-BY-SA-4.0, then under "Open-source licenses" Fredoka's OFL.txt, Lota's NOTICES.txt and the files at the top of Fledge's `notices/`, each only when the running build carries it. The words have room for a later "Thanks to" line (`thanks:`), left out while there is none. `Shell::NoticeFiles` looks for the texts in the game's folder and in the folders above it and above the program, up to four levels, nearest first, because the fused layouts differ: `NOTICES.txt` lands in the app's `app` folder, Fledge's `notices/` beside `app` on a computer and with the game's own files on a phone. The stick and d-pad scroll the page there instead of moving the gamepad's cursor, and Y holds nothing.

**Why:** The app stores want licenses readable inside the app, since players cannot open the app's folder, and players expect a Credits screen. Searching upward finds the files without knowing the platform, and a build with none of them still shows the rest.

**To reverse:** Drop the Credits pill from `Show#records_controls` and `Show#open_credits`; the rest is unreachable and can go with it.

### The setdef splash is drawn in the Shell, timed in Presentation, and leaves out what is timed

For about 1.4 seconds before the title, or 3.5 with sound (a 0.25 s fade in, a hold, a 0.3 s fade out), setdef's logotype shows on its near-black: "setdef" in Iosevka Bold, then a block like a text cursor, in Workshop Yellow, with a faint glow on the letters only. `Presentation::Splash` is the timing and `Logotype` the measures, taken from setdef's artwork; `Shell::SplashPainter` draws them, the glow as the letters blurred by the same `Shell::Bloom` the dots use, added faintly in yellow, so where there is no blur shader there is no glow. A tap, click, key or gamepad button ends it and goes no further, so it can never touch the game. It is silent. The bot, the GUI director and `DOT_POPPER_NO_SPLASH` leave it out, so tests and timings are as they were.

**Why:** The game is setdef's, and the splash says so once, quickly, without making anyone wait: it is skipped by any press.

**To reverse:** Drop `@splash` from `Shell::App` and the splash arguments of `Renderer#draw`.

### The splash follows setdef's brand master spec: amber, its glow, and a steady block under calm

setdef's brand README (`setdef.com/brand/README.md`) is decided, and the splash follows it. The mark is `#fbbf24` (`SPLASH_YELLOW`; the maintainer chose it over the retired `#F2C24B` in two blind rounds), on `SPLASH_INK` `#09090b`, which stays: the spec names `#101012` as the website's dark ground but does not require it elsewhere, and the game's near-black is shared with nothing else. The glow is the spec's: the mark blurred, in its own colour at 55%, under the crisp mark, letters and block together, the block's following its lit level. The spec says "a blur of 0.12em", but its artwork's filter is a Gaussian of standard deviation 60 in 1000 units, 0.06em, so the screen matches the artwork. `Logotype#glow` makes the `Bloom`'s look from the logotype's size: three passes of sigma 3 spread over 5.2 blurred pixels, and the blurred layer's resolution is set so that is 0.06 of the size in device pixels (resolution 1 at the smallest sizes, with a gentler sigma), so the blur scales with the window and the screen's density; `SplashPainter#refresh` makes it again on a resize. It is added to the ground rather than composited over it, which differs from the SVG's filter by a hair on a near-black ground. Where there is no blur shader there is no glow. The spec also says a blink stops under reduced motion, so with `DOT_POPPER_CALM=1` the block stays steady and lit, as when muted, while the jingle still plays if sound is on and the splash lasts as long as it does.

**Why:** The mark is setdef's, and the brand's own file is the authority for how it looks and behaves.

**To reverse:** Put the old colour in `look.rb`, give `SplashPainter` a fixed `BloomLook`, and drop `calm` from `Splash`.

### License texts are set in Iosevka, wrapped with their indentation kept

On the Credits screen the license bodies are in Iosevka Regular, a monospace face, while headings, "Made by" and the summaries stay in Fredoka. A monospace face keeps the texts' columns and numbered clauses as their authors set them. Each line is wrapped to the window's width and every piece of it keeps the line's leading indentation, so a long clause continues under itself and nothing ever scrolls sideways. Iosevka's own OFL, with its copyright line, is among the open-source licenses.

**Why:** The license texts are written to be read as plain text, with indents that carry meaning; Fredoka's proportional letters lose them.

**To reverse:** Set `legal` blocks in the semibold face again in `CreditsLines.broken` and `CreditsPainter`.

### The app identifier is com.setdef.DotPopper

Every build now uses the identifier `com.setdef.DotPopper`, which was `com.kerricklong.DotPopper`: the macOS and iOS bundle ID, the Android application ID, and the Linux desktop entry's name, all taken from `fledge.yml` and the workflows' `IDENTIFIER`. The MSIX identity's placeholder is now `setdef.DotPopper`, which was `KerrickLong.DotPopper`. The save folder's name, `t.identity`, stays `dot_popper`.

**Why:** setdef is the maker a player or a store sees, and an identifier can't change once a store knows the app, so it changed before any store submission. To the system, test builds already installed under the old identifier are a separate app. They stay beside the new one until someone removes them, and on iOS and Android their saves don't carry over, since each app's files live under its identifier there. On a computer the save folder is named by `t.identity`, so both builds share it.

**To reverse:** Before any store has the app, change the identifier back in `fledge.yml`, the workflows' `IDENTIFIER`, `MSIX_IDENTITY_NAME`'s default, and the docs.

## Only OpenGL on Windows and Linux

*Windows since went back to Vulkan first: see "Vulkan first on Windows, for the Xbox overlay".*

LÖVE tries its renderers in a fixed order, Vulkan first, but falls back only when a renderer can't be created at all. A computer with a Vulkan driver but no GPU it can use (old integrated graphics, a virtual machine, a remote desktop, a display server like Xvfb) gets "Failed to initialize graphics" and can't play. That was found on the maintainer's Linux machine, and Lota keeps LÖVE's behavior here by design: the choice is the game's, in `conf.rb`. LÖVE tries renderers in its own fixed order whatever order a game lists, so a game can put OpenGL first only by leaving Vulkan out. Dot Popper allows only OpenGL on Windows and Linux: OpenGL is the renderer LÖVE has supported longest and runs nearly everywhere, and a game this light gains nothing from Vulkan on a computer. Android kept Vulkan first at the time (since reversed: see "Android draws with OpenGL ES until Lota fixes Vulkan's backgrounding crash"), since a blind playtest on a OnePlus Nord rated OpenGL ES "stuttery" on battery and Lota 0.2.2 fixed Vulkan's landscape slowdown there. macOS and iOS have only Metal. `DOT_POPPER_RENDERERS` still overrides the order for testing.

## Phone builds write their own NOTICES.txt

**Decision:** `script/phone_notices.rb` writes the Android and iOS apps' `NOTICES.txt` by calling Lota's `Lota::Notices` with the works Lota's `licenses.rb` records for each phone, rather than hand-written text.

**Why:** Lota 0.2.2's `lota fuse` writes this file for desktop only, and the phones left Credits without FreeType's credit, and (on Android) without OpenAL Soft's LGPL text and source offer. Using Lota's own record keeps one source of facts and the same format. The Android app's `licenses/` folder already carries OpenAL Soft's exact source archive, so that is the source offer; no release asset or written offer is added.

## Vulkan first on Windows, for the Xbox overlay

On Windows, in fullscreen, the Xbox button opened the Xbox Game Bar's overlay out of sight: the overlay took the controller, so Dot Popper's cursor stopped, but it never drew over the game. The maintainer tried the four combinations on his PC, which is connected to a TV:

| | TV's game mode | Xbox overlay | Alt+Tab |
|---|---|---|---|
| OpenGL, borderless (0.9.2) | yes | no | instant |
| OpenGL, exclusive | yes | no | disruptive |
| Vulkan, borderless | no | yes | instant |
| Vulkan, exclusive | no | yes | barely worse |

No combination gave both. He chose the working overlay. Windows now allows both renderers, and LÖVE's own order puts Vulkan first on x64 (and OpenGL first on ARM64, whatever a game lists). LÖVE falls back to OpenGL only when Vulkan can't be created at all, and Lota matches LÖVE there on purpose, so a Windows PC with a Vulkan driver but no usable GPU (a virtual machine, a remote desktop) may fail to start. That's the risk the Linux choice above avoids, and it was judged rare on Windows. `DOT_POPPER_RENDERERS=opengl` still starts the game there. Fullscreen stays borderless, which matched exclusive on both counts and has the better Alt+Tab. `DOT_POPPER_FULLSCREEN=exclusive` stays as a switch for testing.

**To reverse:** In `conf.rb`, match `mingw|mswin` again along with `linux` for the OpenGL-only list.

*The risk is since covered: see "When Vulkan can't start the game, it starts again without it".*

## When Vulkan can't start the game, it starts again without it

**Decision:** When Vulkan fails to start the game, the game notes the day in its save folder (`vulkan_failed.txt`) and at once runs itself again with `DOT_POPPER_NO_VULKAN=1`, which leaves Vulkan out, so LÖVE takes OpenGL on Windows. The player sees one slower start, not an error. For 30 days after, `conf.rb` reads the note and leaves Vulkan out from the start. Then the game tries Vulkan again, and if it still fails, falls back again by itself. `Presentation::RendererChoice` decides the renderers and which errors it rescues, `VulkanFailure` is the note, `Relaunch` is how the game runs itself again, and `Shell::VulkanRescue` carries them out from `conf.rb`'s `Lota.errorhandler`, which must live in `conf.rb`, since the window opens before `main.rb` loads.

**Why:** Windows allows Vulkan for the Xbox overlay (above), and LÖVE falls back to OpenGL only when Vulkan can't be created at all, so a PC with a Vulkan driver but no GPU it can use (a virtual machine, a remote desktop, old integrated graphics) got "Failed to initialize graphics. Vulkan: failed to find a suitable GPU." and never started. Store certification and reviewers may test in virtual machines. Lota won't add a fallback, by design, but its error handler receives that error, as `love.errorhandler` would. Three ways were weighed:

- A note alone, read by `conf.rb` on the next launch, works only on the second launch, after an error the player has to understand.
- Lota's in-process restart doesn't exist: `Lota::Event.restart` replaces the process under `lota run` only, and a fused game quits instead. Under `bundle exec lota run`, Lota's restart even runs `bundle` again rather than `lota`. LÖVE also picks its graphics module once, when the module opens, so nothing in one process could switch renderers.
- Running itself again works on the first launch. Fledge documents how: on Windows, start the app's `NAME.exe` again, two folders above the program Ruby runs (`ROOT\app\main.rb`); on macOS and Linux, `RbConfig.ruby $0 ARGV`. Under `lota run`, it is `RbConfig.ruby $0 run ARGV`. On Windows, Ruby's `exec` runs the new process, waits for it, and exits with its status, so a script that waits for the game, such as `playtest.ps1` or CI, still sees the real game end.

So the game runs itself again, and the note only spares later launches the failed try. The environment variable, not the note, tells the second run to leave Vulkan out, so a save folder that can't be written still gets the game started, and since the second run has no Vulkan to fail, it never starts a third. Where the game can't run itself again (a phone, or a Windows app whose `.exe` isn't where Fledge puts it), it shows one line, "Dot Popper will use different graphics now. Please start it again.", and the note makes that start work.

`conf.rb` makes `t.identity` the save folder before it reads the note: until `Lota.conf` returns, Lota's save folder is the one named after the game's folder, and the error handler would write elsewhere under `DOT_POPPER_SAVE_AS` or `lota run`.

The note lasts 30 days, not forever, because a driver update or a move from a virtual machine to real hardware can make Vulkan work, and the Xbox overlay is the reason Vulkan is allowed at all. Trying again costs one slower start a month on a PC where Vulkan still fails; never trying again would cost the overlay for good on one where it now works. Delete `vulkan_failed.txt` to try sooner.

The rescue takes only a `RuntimeError` that mentions Vulkan, a suitable GPU, no supported renderer, or the window mode, and only while Vulkan was allowed; anything else goes to Lota's own error screen. Proven on Linux under Xvfb with `DOT_POPPER_RENDERERS=vulkan`, which fails with exactly that message and then played on OpenGL, on a Mac with the same setting (no supported renderer, then Metal), and on GitHub's Windows runner, which has no GPU and no Vulkan loader ("Cannot create Vulkan renderer: could not find vulkan"): the Package workflow plays the fused app allowed only Vulkan and checks that it ran its own exe again, drew with OpenGL, and exited with 0 (run 42448149007). A real Windows PC with a Vulkan driver and no usable GPU hasn't been tried.

**To reverse:** Drop `Shell::VulkanRescue` and its `Presentation` objects, set `t.graphics.renderers` in `conf.rb` from `DOT_POPPER_RENDERERS` as before, and remove `Lota.errorhandler` from `conf.rb` and the Vulkan play from the Windows job.

## "Press B again to quit" goes where there's room

The maintainer saw "Press B again to quit" drawn behind the Play button. It was placed under the title's backing, which ends at the line above Play. The title's plan now places it: a gap under Play, or, where the bottom row leaves no room there, a gap above the name. On the smallest windows, where neither has room, it stands in for today's goal, the best, or the legend, and that line fades out while it shows. It shows for only two seconds, so it takes no room from the other lines, and Play never moves.

**To reverse:** Drop `TitlePlan#quit_line` and `#quit_over`, and draw the prompt in `TitlePainter#quit_prompt` where it was.

## The splash's block blinks like a terminal cursor

The maintainer's idea: setdef's block blinks like an old amber terminal's cursor, in time with the jingle. It lights in 0.03 s and fades in 0.1 s, like a phosphor. He wanted to see two versions, one flipping on each note and one on every beat, and chose the notes ("it going with the music is cute"), so the beat version and its `DOT_POPPER_SPLASH_BLINK` switch are gone. Sounding, the block flips on each note: lit from the first until the second, dark until the third, and so on, so the sixth note leaves it dark. His first version lit it for half the time between flips, which blinked at double the speed he expected; a note should flip the cursor, not blink it fully on and off. The shortest dark span, between the fourth and fifth notes, is 0.25 s, still longer than the 0.1 s fade, so each fade finishes before the next light. Muted, the block does not blink at all: "There's no music to flash to." It stays lit for the whole splash.

He then found the splash too short with sound: the whole thing was fading to the title at the same moment the cursor was fading to black, so the cursor's fade could not be seen. The splash now ends on a held dark block. Sounding, it lasts the last note plus two beats, 3.5 s: dark from 2.6 s, fade out from 3.2 s, so 0.6 s dark first. Muted there is no blinking cursor to hide, so it stays 1.4 s.

**To reverse:** Drop `Splash#block`, and draw the block at `splash.mark` in `SplashPainter`.

### The block glows with the letters

The maintainer's brand decision for setdef's mark: "The block cursor glows exactly when the letters glow, and is flat when they're flat." The block is drawn into the same glow pass as the letters, at its own lit level (`splash.block`), so its glow fades and returns with the blink while the letters' glow is unchanged. Where there is no blur shader, neither glows. Colours, proportions, timing and blink are untouched.

**To reverse:** Drop the `block` call from the glow block in `SplashPainter#draw`.

## The gamepad cursor gathers speed in 0.08 s, not 0.3 s

Release-candidate players said the gamepad cursor's "friction feels like bad delay". The cause was the ramp: the cursor took 0.3 s to reach its speed, so it lagged behind the stick on every push. Swink's *Game Feel* puts "feels direct" below about 100 ms, so the ramp is now 0.08 s. Letting go already stopped the cursor dead, and the squared stick curve still handles fine aiming, so nothing else changed. The d-pad and stick go through the same path with no other smoothing.

**To reverse:** Set `ramp:` back to `0.3` in `Look::GAMEPAD` (and its comment).

## A worn mouse's double click is dropped

A release-candidate player's worn mouse sent one click as two. The first popped the bright dot, and the second landed on the popped dot it left behind, a slip that cost 2 points and 2 seconds. A loss has to feel like the player's own (Juul, *The Art of Failure*), and a switch's chatter isn't. So a press of a mouse button less than 0.06 s after that button's last press, and within 8 units of it, is dropped, and so is its release, so a drag on the pile never sees a stray one (`Presentation::Chatter`, its numbers in `Look::CHATTER`). A switch's bounce is under 0.02 s and a failing one chatters at 0.05 to 0.08 s, while a hand clicking twice as fast as it can takes 0.1 s or more. 8 units is `MouseTravel`'s line between a jitter and a nudge. Each press is timed from the last press of its button, dropped or not, so a run of chatter is dropped whole. The clock is the frames' unclamped time, so the GUI suite's scenarios, whose frames are a sixtieth of a second of game time however fast they draw, play as they did. The autopilot and the fake drag never come through the mouse, so they are untouched.

This is the one exception to "every press goes to `game.press` on the same frame", and the maintainer approved it as a narrow one: a press is still never held back. It is heard on its frame, exactly as before, or dropped. It is dropped whatever it would hit, on every screen, the splash included, so the rule is simple and never depends on whether the press would have been a slip. Only the mouse is filtered. Several fingers can land together on purpose, and a gamepad's buttons don't chatter this way.

**To reverse:** Drop `App#chattered?` and `#released_chatter?` and their calls in `mouse_pressed`, `mouse_released` and `focus`, then `presentation/chatter.rb`, `Look::CHATTER` and its test.

## The privacy manifest declares two required-reason APIs, not four

The manifest began with four categories from a reading of Apple's list: FileTimestamp (C617.1), SystemBootTime (35F9.1), DiskSpace (E174.1) and UserDefaults (CA92.1). Lota's audit of what the iOS app links (LÖVE, SDL 3.4.10, the prebuilt libraries, Lota's iOS host and Fledge's runtime) found only the first two, which are also the two Fledge's template declares. Our file replaces Fledge's whole, so it keeps both. Dot Popper's own code uses neither of the others: it saves through `Lota::Filesystem` read, write, remove and `info` (to see whether a file exists), never shows a file date, and asks for no free space or user defaults. Declaring a reason the app doesn't use is inaccurate. SDL's read of `com.apple.swipescrolldirection` goes through CFPreferences, which isn't on Apple's list, so nothing is declared for it. App Store Connect's validation still has the last word.

**To reverse:** If validation asks for them, add back the DiskSpace (E174.1) or UserDefaults (CA92.1) entry to `ios/host/Host/PrivacyInfo.xcprivacy`, and add DDA9.1 if the game ever shows file dates or 3B52.1 if the app declares document types or a file picker.

## "Share my score" shows the result before anything is copied

Game Over's "Copy my result" is now "Share my score" (with "(Y)" on a gamepad). Pressing it opens a card over Game Over that shows exactly the text that would be shared, under "Share your score", with two buttons, Close and Copy (it first said "Copy it, then paste it anywhere." too; see "The share card drops its line on what Copy does"). Only Copy writes the clipboard; then "Copied! Paste it anywhere." shows with a check, and the card stays open until it's closed. Copy is the card's filled gold button, so Enter, Space, Start, A aimed at nothing, and Y again all copy. Close, Escape, B, and a tap or click beside the card close it. The preview belongs to the presentation alone (`Show#sharing?`): the game stays on Game Over, its grace runs as before, nothing under the card takes a press, and Continue works as before once the card is closed. Fredoka has no emoji, so the preview draws 🟡 as the game's bright dot, ⚫ as a popped dot, and ⏱ as a small stopwatch, made of shapes (`ShareGlyphs`). The copied text keeps the real emoji. A line of facts wraps only after a "·".

**Why:** "Share" invites people to share more than "Copy" does, but a button named Share that quietly replaced the clipboard would surprise people. Showing the text first makes clear what goes out, and Copy is the player's own choice. Lota has no share sheet. The preview arrives through `Show`'s `sharing:` (`InGameSharing#offer`), so a phone's native share sheet can replace it later: its `offer` would hand the text to the system and return nil, and no preview would open.

**To reverse:** Have `Show#share` copy at once, as `copy_result` does, and put "Copy my result" back in `Look::WORDS`; the preview's plan and painter can then go.

## "Share my score" sits with the score, and rises in as it lands

Players didn't see "Copy my result" under Continue. "Share my score" now ends the score's group: it sits under the round's facts and any record, inside Game Over's dark backing, above the pile hint and Continue. It's a dark pill outlined in a bright dot's gold, with a share glyph drawn from shapes (a bright dot joined to two cream dots). It stays quieter than Continue's filled gold. It is hidden until the score has counted up. Then it rises 12 units into place, bounces a little past its spot, and a gold ring spreads from its edge and fades. On a new best it waits 0.15 s more for the celebration, rises 28 units, and rings brighter and wider. Its reach doesn't move while it rises. `FinaleScreen` still drops it, at the same rank, when the screen is short of room. `ScreenPlansTest` now also lays out the share preview at every window size, with the longest results and each input's words, and checks the buttons' reaches with the preview open.

**Why:** Proximity and enclosure (Johnson's Gestalt chapters) make the button read as part of the score. Motion as the score lands draws the eye at the moment a player is proudest, and the stronger cue on a new best matches that moment. An outline instead of a fill keeps Continue the one obvious way on.

**To reverse:** In `FinaleScreen#blocks`, move `share` back after `continue(scale)`, leave `:share` out of the backing again, and draw it with `PillButton` at the finale's arrival alpha instead of `ShareButton` and `Finale#share_cue`.

## Continue stays off the pile's bottom row

Game Over's words now end a radius above the window's floor, where that is higher than a margin above the safe area's bottom (`FinaleScreen#room`). So the filled Continue, the lowest block, never covers more than the upper half of a dot lying on the floor. Moving "Share my score" above Continue had put Continue last, and on any landscape window short enough for the words to fill the room, it covered up to 87% of the bottom row's height under the middle of the screen (as much as 19% even at 1200 × 800). On a 1200 × 450 window, the GUI suite's resizing scenario found the bright dot left in the pile hidden behind it. Before, the outlined share pill had been lowest, and the pile showed through it. On the shortest windows this costs a line: the hint, or the round's facts, goes sooner. `ScreenPlansTest` checks Continue's bottom at every window size and combination of lines.

**Why:** The pile shows how the round ended, and the stacking order must stay visible. A bright dot lying on the floor under a solid button is no longer distinguishable from a popped one. Half a dot shows its fill or its ring plainly. Reserving a whole dot's width would have cost landscape phones "Time's up!" and the best line as well.

**To reverse:** In `FinaleScreen#room`, end the room a margin above the safe area's bottom again.

## On a phone, "Share my score" opens the system's share sheet

On iOS and Android, Share my score hands the result's text to the system's share sheet (`UIActivityViewController`; a chooser over `ACTION_SEND`, `text/plain`), and no in-game preview opens. Computers keep the preview. Lota binds only what LÖVE has, and LÖVE has no share call, but it can open a URL (`Lota::System.open_url`, `SDL_OpenURL`). So `Presentation::SheetSharing` opens `dotpopper-share://score?text=…`, and each host catches that URL before it leaves the app: on iOS, `DotPopperApplication` (`ios/host/Host/main.m`, Info.plist's `NSPrincipalClass`) overrides `canOpenURL:` and `openURL:options:completionHandler:`, which SDL calls; on Android, `MainActivity#startActivity` (`android/host`), which SDL's `openURL` calls to start its `ACTION_VIEW` intent, starts the chooser in its place. If the host won't take the URL, `open_url` returns false and the preview opens instead.

**Why:** Players on a phone expect the phone's own sheet, which reaches Messages, chats and notes in one tap. Catching the URL in the host, rather than registering a URL scheme and an activity for it, means no other app can send the game that URL, no round trip through the system and no disambiguation dialog, and the game keeps its focus. All the native code lives in the host files Dot Popper already owns, since a gem can't add to the host. The text is percent-encoded as RFC 3986's unreserved characters, so a space is `%20` and a plus `%2B`, which iOS's and Android's parsers both decode alike.

**To reverse:** Pass `InGameSharing.new` as the Show's `sharing:` in `Shell::App#load` (or drop `SheetSharing` and `UrlOpener`), then remove `DotPopperApplication` and `NSPrincipalClass` from `ios/host`, and `startActivity` from `android/host`'s `MainActivity`.

### The tutorial's first dot starts left of the middle

The tutorial's first bright dot starts about a quarter of the window's width left of the middle and a little above it, and drifts further left, so it freezes well away from the centre on every window size (at least 3 radii, inside the safe area, clear of the HUD and the skip button). The next dot is born under it and slides out toward the middle.

**Why:** A gamepad's cursor starts hidden in the middle of the screen. With the dot there too, the player's reticle sat on the ghost's, and nobody had to aim. Now the cursor, pointer or thumb must travel to the dot.

**To reverse:** Set `TUTORIAL.start` back to a small offset and the first dot's `velocity_x` positive.

## On Android, the game rides out dark theme, font size and overlays

Dot Popper's Android activity now declares that it handles dark theme (`uiMode`), font size (`fontScale`, `fontWeightAdjustment`), language (`locale`, `layoutDirection`, `grammaticalGender`), a SIM (`mcc`, `mnc`), `touchscreen`, `colorMode`, and overlays (`assetsPaths`), as well as turning and keyboards. Before, any of these made Android destroy and recreate the activity. SDL can't survive that: `onDestroy` quits the game, and the new activity's `onCreate` logs "activity finished" and calls `System.exit(0)`. On an API 33 emulator, switching dark theme on, changing the font size, or turning on a font overlay each ended a running round. Turning on a font overlay is the kind of overlay change Android 12 and newer also make when a wallpaper's colours change. Android also applies an overlay update to a just-installed app. When that update lands after the first launch has begun, the activity is recreated before the game prints anything, which is the Android job's first-launch flake (it hit on 1 of 5 cold boots on an emulator here). With the new list, the same changes reach SDL's `onConfigurationChanged` and the game carries on. `assetsPaths` is in `android.jar`'s `configChanges` flags, though the docs don't list it. Density (Display size) was left off the list at first, as in SDL's own manifest; the next entry adds it.

**Why:** A player who switches on dark theme from Quick Settings, or whose phone does that at sunset, mid-round, shouldn't lose the round and the app.

**To reverse:** Cut `android:configChanges` in `android/host/src/main/AndroidManifest.xml` back to `orientation|screenSize|smallestScreenSize|screenLayout|keyboard|keyboardHidden|navigation`.

## On Android, a new Display size no longer ends the game

The activity's `configChanges` now also lists `density`, so changing the system's Display size (`adb shell wm density`) mid-round no longer recreates the activity, which SDL can't survive. `screenSize`, `smallestScreenSize` and `screenLayout`, which a density change also flips, were already there. The game carries on at the density it started with: LÖVE reads the dpi scale once (`love::android::getScreenScale` keeps it in a static), the window's pixel size doesn't change, so no `Lota.resize` arrives, and SDL only reads the density again when the surface changes. Everything the game draws and every hit area uses that one scale, so the layout stays whole and the dots keep their size on the glass; the new Display size applies from the next launch. There is nothing for the game to watch for, since its dpi scale can't change while it runs, so no game code changed.

On an API 33 emulator (a Pixel 6 profile, 1080 × 2400 at 420 dpi), the game went from 420 to 560, 320 and 480 dpi and back, on the title and mid-round, with LÖVE's Vulkan renderer and with OpenGL ES (`DOT_POPPER_RENDERERS=opengl`), all on SwiftShader: the process kept its pid, rounds played on to Game Over, nothing logged a crash or "activity finished", and the screenshots showed the same layout before and after. The open Vulkan bug (presenting after the surface is destroyed) never fired, since a density change leaves the surface alone. The same APK without `density` exited at the first change. Only the system's own "Viewing full screen" notice rescaled. The insets Android reports for the screen's rounded corners do change with density, but the game keeps the safe area it measured at launch, which still matches the glass.

This overrides the earlier entry's "density stays off, as in SDL's own manifest": that reasoning held only if the game could re-lay itself out at the new density. It can't, and doesn't need to, and quitting was the worse outcome.

**Why:** A player who changes Display size, or whose phone's accessibility settings do it, mid-round shouldn't lose the round and the app. Keeping the launch scale until the next launch is consistent and safe; a game that quit was neither.

**To reverse:** Take `density` out of `android:configChanges` in `android/host/src/main/AndroidManifest.xml`. If Lota or LÖVE ever report a changed dpi scale while running (by not caching `getScreenScale`, and with a resize or display-scale event), the game's `Shell::App#resize` already re-reads the scale, fonts and safe area, and only needs calling.

### The tutorial hands its dots, score and time to the first round

When the tutorial ends, the first round begins from exactly where it left things: its three dots where they are, going as they go, the two popped ones on top and the bright one under them, and the score and the clock at whatever the tutorial's taps left them: 1 and 10 after its two pops and the guide's wrong tap, less for a player who also tapped a popped dot. Only the clock starts, with the lit TIME and the tick the tutorial already had. Nothing fades, nothing resets, and no dot is added. `Round.resume(field, dots:, score:, seconds:)` starts a round from a given state, and `Game#resume` starts it from the title; from there the round plays by the usual rules (a new dot spawns under every dot, a tap reaches only the topmost, the clock runs from its first update), and its score, best, records and daily goal count as any round's. `RoundStats` counts each carried popped dot as a pop with no wait, so the score and the pops agree. Skipping the tutorial still starts a fresh round at 0 and 10.

**Why:** This is not an exception to "nothing affects the score or the timer outside Playing". It is that rule applied: the clock is paused whenever the game isn't running, and the tutorial is a time when it isn't. The tutorial's two pops are pops by the usual rules, made while the clock was still, so the round keeps them, and the clock simply starts. The old ending taught something the game never does, a field emptied and a score taken back, which the maintainer saw at once. A demonstration should show what really happens (Hodent, on teaching by the game's own feedback), and an ending that carries straight on asks the player to unlearn nothing.

**To reverse:** In `Show#follow_tutorial`, call `start_round` instead of `game.resume`, and in `Show#round_started` treat every round as fresh.

### The tutorial's guide shows a wrong tap's cost, with no ✕

The soft pink ✕ that marked the popped dot in the tutorial is gone. Instead, as the bright dot peeks out, the guide taps the popped dot once, and the game's own penalty plays: the dot's shudder and alarm ring, the dashed outline of the bright dot under it, the edge's glow, the bonk, and "−2" and "−2" with the stopwatch leaping out of SCORE and TIME. Then the guide lifts and waits well above the popped dot, clear of both dots, while the bright one slides clear, and only then moves to it and taps. The guide's tap lands before the player's turn, under the spotlight, with the guide plainly pressing, and it doesn't buzz a phone, so it can't be mistaken for the player's own. *Later: the guide's wrong tap and the player's own now cost what they do in play (see "Every wrong tap in the tutorial costs what it does in play").*

**Why:** Symbols and colours are not universal (Westland & Maggio on colour). On ballots and checkboxes in the UK and the US an X marks the voter's choice, "X marks the spot" means "here", in parts of Scandinavia a ✓ means wrong, and in China and on East Asian stock tickers red and pink mean good, or up. The game's own penalty needs no translation, since the player will see it again in every round, and showing a consequence teaches better than a sign forbidding it (Hodent).

**To reverse:** In `Tutorial#show_the_cost`, hover the guide over the popped dot (`ghost.hovering`) instead of tapping it, and drop the cue that calls `guide_slips`.

### "How to play" on the title replays the tutorial

The title's bottom row has a small, quiet pill beside the mute button, "How to play", with an icon: the help sign, a "?" in the game's semibold face centred in a thin ring, the same for every input. *Earlier, the icon was the tutorial's guide in miniature, drawn as the hand in use, tapping a small bright dot; see "How to play's icon is the help sign".* Pressing it opens the tutorial at once, on any title, whether the tutorial was seen or not, and it hands over into a real round as a first Play's tutorial does; the seen flag keeps its meaning, and the first Play still opens it only once. H does the same from the keyboard, and so does Y on a gamepad, which has nothing to share on the title (on Game Over it shares, on the Records screen it clears); the gamepad's cursor reaches the button as it does any other, and its label then says "How to play (Y)". `Layout#how_to_play_button` puts it between "Your records" and the mute button, 3.8 buttons' heights across, or as little as 3.1 where the room is short; where even that won't fit, as on a phone 375 points wide held upright, it takes a row of its own above the mute button, set apart as the dot-size choice's row is, and the dot-size choice, where it can't sit between "Your records" and "How to play", goes a row above that. The title's words fit in what is left, by the plan's usual rules.

**Why:** The maintainer hands his phone to playtesters, and every player may want to see it again: people forget what they learned once (Hodent, *The Gamer's Brain*), and a tutorial a player can't call up again leaves them without control (Lidwell, Holden & Butler, *Universal Principles of Design*, on control). Saffer (*Microinteractions*) warns against hidden triggers, so it is a visible button, not a secret key. An icon with a short label is understood faster and more surely than either alone (Johnson, *Designing with the Mind in Mind*), and the icon is the very hand the tutorial shows, so it says what the button opens before a word is read. It is quiet and in the corner, so Play stays the one thing to press.

**To reverse:** Drop `:how_to_play` from `Show#title_controls`, `Layout#how_to_play_button` from `TitleScreen#bottom_row`, its pill from `Shell::TitlePainter#draw`, and the H key and the title's Y from `Shell::App`.

### Every wrong tap in the tutorial costs what it does in play

*Reverses the part of "The tutorial's guide shows a wrong tap's cost, with no ✕" that had its wrong taps cost nothing.*

In the tutorial, the guide's tap on the popped dot and every tap of the player's on a popped dot apply the game's penalty to the tutorial's own numbers, as `Round#penalize` does: two points, never below 0, and two seconds, never below 0 (`Countdown` never reads less). The HUD drops the moment the cost leaps out of SCORE and TIME. As in play, a floor that kept a number from falling says only what was lost: the guide's tap comes when the score is 1, so it shows "−1" and "−2" with the stopwatch, and the score goes to 0 and the clock from 11 to 9. The clock stays still, so a wrong tap can never end the tutorial, and the last pop always adds its point and second. The round then goes on from whatever is left: 1 point and 10 seconds after the guide's tap alone, and as little as 1 point and 1 second for a player who kept tapping the popped dot.

**Why:** The penalty played its feedback while the numbers stayed at 1 and 11, so the tutorial showed a cost that was never taken. Players learn the pattern they see, not the one we mean (Koster, *A Theory of Fun*), and a tutorial teaches through the game's real feedback, so what it shows must be what the game does (Hodent, *The Gamer's Brain*). A "−2" that takes nothing teaches that a wrong tap is harmless. Failing stays safe, since the clock is still and nothing can be lost but numbers the player can win back (Juul, *The Art of Failure*), but it is true. Every player no longer starts the first round from the same numbers, and that is the point: the round starts from what they did.

**To reverse:** In `Tutorial#slip`, fly out the full cost with `fly_out` and leave the HUD as it is, instead of calling `penalize`.

### The title's legend is the tutorial's signs, not sentences

The title's two sentences, "Click a bright dot: +1 point, +1 second" and "Click a popped dot: −2 points, −2 seconds" (with Tap and Pop or Hit for other hands), are gone. In their place, a bright dot stands before "+1" and "+1" with the drawn stopwatch, and a popped dot before "−2" and "−2" with the stopwatch, in two columns that line up. They are the very numbers, colours and stopwatch the tutorial flies into the HUD (cream and green for a pop, pink for a wrong tap), drawn by the same `Shell::TallyPainter` from the same `Presentation::Tally`, so the title and the tutorial speak one language. `Presentation::Legend` lays it out, and `TitleScreen` measures it, so the title's plan holds on every window size as before.

**Why:** How to play must never depend on reading, and the maintainer's goal is that a person who can't read English should understand and enjoy the game. Reading is a learned skill, and recognizing something already seen is far easier than recalling it (Johnson, *Designing with the Mind in Mind*): a player who has watched "+1" and the stopwatch fly into the HUD recognizes them at once on the title, so the legend stays as a reminder without a sentence. It also omits needless words (Strunk).

**To reverse:** Give `Words` its `legend` back, and draw the two sentences in `TitlePainter#legend`, measured by `TitleScreen#legend_width`.

### Game Over teaches the stacking rule by replaying the wrong tap

Game Over's two sentences, "New dots appear under the popped ones. Wait for the bright dot to slide out, then tap it.", are gone. Under the same conditions as before (a round in which the player tapped a popped dot with the bright one hidden under it, on at most two Game Overs, counted in `taught.txt` as before), that wrong tap replays on the pile, in the game's own penalty look: the popped dot that was hit shudders and its alarm ring flashes, the dashed outline of the bright dot it hid draws over the other dots, and that bright dot pulses with a soft ring. These marks are drawn at the pile's own depth, under the veil that dims it and under Game Over's card, its backing and its buttons, so they read as part of the pile, as its dots do, and never cross Continue; they show wherever the pile does, as on its lower half, which the layout keeps in view. It replays once the score has counted up, then twice more 2.4 s apart (`Look::LESSON`), and then the pile is left in peace. It makes no sound, the screen never shakes, every mark is a thin outline that hides no dot, and Continue works as before. The effects follow the two dots by id wherever the pile throws them. If the bright dot was popped later in the round, nothing on the pile shows which dot it was, so Game Over shows nothing, and that Game Over isn't counted (`Slip#among`). There is no ✕, for the reasons in "The tutorial's guide shows a wrong tap's cost, with no ✕".

**Why:** How to play must never depend on reading. Failure is the moment a player is ready to learn (Juul, *The Art of Failure*), and showing the consequence where it happened teaches better than a sentence about it (Hodent, *The Gamer's Brain*). The player already saw this penalty in the round, and the tutorial showed it too, so the replay needs no words to be read as "that's what happened, and that's the dot you couldn't see".

**To reverse:** Give `Words` its `covered` lines back, pass them to `Tutor#lesson` in `Show#round_ended`, lay them out again in `FinaleScreen#blocks`, and drop `Show#replay_slip`.

### Game Over leaves the pile to be found by touch

Game Over's light line about the pile, "Drag the dots to play with them." (or "Drag the dots, or tilt your iPad to roll them.", or the right stick's line with a controller), is gone, with `TiltHint`, its painter, its words in `Look::TILT`, and its place in `FinaleScreen`. The pile still tumbles, drags, tilts and rolls exactly as before. `tilt_hint.txt`, which counted the line, is no longer written; the records' clearing still leaves it alone where an older version wrote it.

**Why:** The pile is a toy, and a toy is found by playing with it (Sicart, *Play Matters*): the dots fall in front of the player, and the first touch that moves one says more than the sentence did. The sentence explained something a player discovers in a second, to a player who may not read English, and how to play must never depend on reading. Omit needless words (Strunk).

**To reverse:** Bring back `TiltHint` and `TiltHintPainter`, pass `hint:` to the `Show` and `Tilting`, and give `FinaleScreen#blocks` its hint line again.

### The share card drops its line on what Copy does

The share preview no longer says "Copy it, then paste it anywhere." under the result. The card keeps that line's room, so when Copy is pressed, "Copied! Paste it anywhere." and its check appear in place and nothing moves. `ShareScreen` sizes the room for the confirmation alone.

**Why:** Words stay where they are the clearest tool, and the confirmation is one: it tells the player that something invisible happened and where it can go next. The line before it only restated the Copy button beside it. Omit needless words (Strunk); every sentence on screen is one more a player who doesn't read English has to get past.

**To reverse:** Put `share_note` back in `Words` and `Look::WORDS`, measure it again in `ShareScreen#note_line`, and draw it in `SharePreviewPainter#note` until Copy is pressed.

## Android draws with OpenGL ES until Lota fixes Vulkan's backgrounding crash

**Decision:** `conf.rb` (via `Presentation::RendererChoice.usual`) allows only OpenGL ES on Android, as it does only OpenGL on Linux. `DOT_POPPER_RENDERERS=vulkan` still overrides it, so Vulkan can be re-tested on a device.

**Why:** With Vulkan the game crashes whenever it goes to the background (HOME, an app switch, or the share sheet sending to another app): a segfault in Lota's `Graphics.present` after `surfaceDestroyed`. On the maintainer's OnePlus Nord (Adreno 619) Vulkan crashed in 6 of 6 background cycles, and OpenGL ES in 0 of 6 (real device, 2026-11-07). Lota is root-causing it. Android had kept Vulkan because a blind playtest found OpenGL ES "stuttery" on battery, before Lota 0.2.2 fixed Vulkan's landscape slowdown. A crash on every app switch is worse than stutter. The Windows Vulkan rescue is unaffected: Android can't start itself again, and with Vulkan out of the list `rescues?` never fires there.

**To reverse:** When a Lota release fixes the crash, make `RendererChoice.usual` return nil for Android again, and confirm six background cycles on the device.

### The tutorial's touch guide is the pointing-hand emoji

For touch, the tutorial's guide is the emoji everyone knows for "tap here": 👆, Noto Emoji's backhand index pointing up (U+1F446), in its default yellow (`Presentation::PointingHand`, drawn by `Shell::GhostPainter`). It replaces the cream glove the game drew from rounded rectangles and capsules. It stands upright, its fingertip on the point it taps and the hand below it, so it hides only the lower part of the dot. Near the right edge it is mirrored, never turned; it is never turned upside down near the bottom either, since an emoji upside down looks wrong and the tutorial's dots stay well clear of the bottom. Each tap still presses it in a little smaller, two thin rings still ripple from the fingertip, and it still fades in and out. The picture is 3 radii square, the hand about 2.8 radii tall. The mouse pointer and the gamepad's reticle are unchanged.

LÖVE cannot draw the system's colour emoji fonts (Apple's are sbix, Android's CBDT), and Apple's artwork may not be shipped, so the game ships Noto's, which is Apache-2.0 (`assets/emoji/README.md`). `script/make_hand.rb` renders its SVG to square PNGs of 48, 64, 96, 128, 192, 256, 384 and 512 pixels, each clear pixel given the colour of the hand's nearest pixel, so no dark fringe can creep in. The game loads the smallest that has at least the pixels the hand needs at the screen's density, with mipmaps and linear filtering, and draws it that size, so it is drawn at most a step smaller than its pixels, never larger, the way an icon is drawn. Its credit and license are on the Credits screen, after Iosevka's.

This keeps "render 1:1 at native resolution". That rule is about the game's frame: nothing is drawn into a fixed-size canvas and scaled to the window, and text is set at its true pixel size. The frame is still drawn at the window's own pixels. Only this one picture is resampled, down from a larger one, as every image drawn at a size its file does not have is. A PNG of the exact size cannot be made ahead of time, since the hand's size follows the dot's radius, which follows the screen and the dot-size choice, and it eases smaller as it presses.

**Why:** The maintainer, on his Android phone, said the drawn glove "looks like a pile of white sausages attempting to imitate a mummy hand. Why can't you just use a system emoji pointer hand?" A guide nobody recognizes teaches nothing. People recognize a familiar picture far faster than they decode a drawing of one (Johnson, *Designing with the Mind in Mind*, on recognition), and a player has seen this emoji in every chat. It is the artwork itself, so it looks like the emoji, not like an attempt at it. Its yellow is the emoji's default, which names no skin colour.

**To reverse:** Draw `:touch` in `Shell::GhostPainter` with the glove of the project's history (`PointingHand::PARTS`, before this change), and remove `assets/emoji`, `script/make_hand.rb` and Noto's credit (`Notices#emoji`).

### The tutorial's reward comes out of the bright dot

In the tutorial, a tap on a bright dot no longer turns it into a popped dot, with a new bright one born under it, the moment it is tapped. The pop's burst, shockwave, sound and buzz play at the tap, over the dot still bright, and time freezes at that instant; the spotlight stays on the dot until "+1" leaves it, and then follows the numbers into SCORE and TIME. Only as time flows again does the dot take its popped look, with its squash, and the new bright dot is born under it (`Tutorial#settle`). The last pop is staged the same way: its numbers fly while it is still bright, and it darkens and spawns the round's bright dot under them all as the light moves to the clock. A second tap on the bursting dot does nothing. The guide's own tap never pops a dot, so it needs no staging.

**Why:** The maintainer, playing it on his phone: "The tutorial's pause to show +score, +time happens after the dot changed to dark and the new one is beneath, barely visible. That's confusing, and makes it almost seem like the dark dot is what gave that." The cause and its reward were split apart. Feedback should come at the moment of the action, from the thing acted on (Swink, *Game Feel*), and things that change together are read as one (the Gestalt principle of common fate), so the "+1" must leave a dot that still looks like the one the player tapped (Hodent, *The Gamer's Brain*). It stays truthful: in play, the darkening and the spawn happen at the pop's instant, and the tutorial has stopped time at exactly that instant, so they take effect when time moves on. The scene the round inherits is the same as before.

**To reverse:** In `Tutorial#pop_bright` and `#pop_next`, call `settle` and spawn the next dot at once instead of in `#resume` and `#hand_over`, and move the spotlight at once.

### How to play's icon is the help sign

"How to play" on the title no longer shows a miniature of the tutorial's guide tapping a dot. Its icon is a circled question mark: a "?" in the game's semibold face, centred in a thin cream ring, on whole device pixels, the same for the mouse, touch and a gamepad. The label "How to play" stays beside it. The tutorial's own guide, the pointing hand, the pointer and the reticle, is unchanged.

**Why:** At the button's size the miniature scene was too small to recognize (Johnson, *Designing with the Mind in Mind*: recognition needs features large enough to perceive), and it changed with the input, so it was never one sign to learn. The circled "?" is the near-universal sign for help, and an icon with a short label is understood faster than either alone (Johnson). The maintainer asked for it.

**To reverse:** In `Shell::TitlePainter#draw`, give the pill's `icon:` a lambda that draws `GhostPainter` tapping `dots.icon` again, as before this entry (in the project's history).


## The game moves by the time between frames starting to draw

`Shell::App#tick`, which `Lota.update` calls, moves the game on by the time between the last two frames starting to draw (`Presentation::FrameClock`), not by the `dt` Lota measured at the top of its loop. With no frame drawn since the last move, as in the background, it counts up to now. Every second is counted once, so the clock and the rules keep time with the wall. The GUI suite's director still steps `App#update` by its scenario's fixed step.

**Why:** On the maintainer's OnePlus Nord (OpenGL ES, 60 Hz) every frame reached the screen 16.7 ms after the last (SurfaceFlinger's frame times), yet Lota's `dt` swung 7.5 ms, 25 ms, 7.5 ms, and so on: 52 to 67 of every 300 frames measured over 20 ms, and the longest in each 5 s 26 to 28 ms. So the dots moved unevenly on an even screen, which is the "not buttery smooth" he felt. Lota steps its timer before it clears the screen, and on Android the clear is where a frame waits for a free buffer, a wait that ends in step with the screen, but after the timer has been read. A frame starts to draw right after that wait, so the time between draws is even: stepping the timer after the clear instead gave 0 to 3 frames over 20 ms in 300, the longest 20 to 22 ms. Measuring between draws gets the same in the game's own code, through `Lota::Timer.time`, without replacing Lota's loop.

**To reverse:** Make `Lota.update` in main.rb call `@app.update(dt)` again. Do that once Lota's own loop steps the timer after the clear, or paces frames by when they are shown.

## On Android, the game asks for the screen's fastest refresh rate

`MainActivity.preferFastestRefresh` sets the window's `preferredDisplayModeId` to the fastest mode at the screen's present resolution. On the Nord that is 120 Hz, where OxygenOS otherwise holds a game's SurfaceView at 60 (its `overrideWindowRefreshRate` puts every SurfaceView app it doesn't list at 60), and the game, drawing with vsync, then draws 120 frames a second. The system still decides: battery saver (on OxygenOS, `power_save_screen_refresh_rate`), the player's own refresh rate setting, and the maker's rules can each hold it slower.

**Why:** Measured on the Nord with the bot playing, OpenGL ES: 120 frames a second at 120 Hz, the longest frame in each 5 s of a round 10.3 to 12.9 ms (one refresh is 8.3 ms), and SurfaceFlinger showing a new frame at every refresh. A frame of a round takes the game about 3 ms (0.4 ms to move on, 2.7 ms to draw), so 120 holds with room; 90 was not needed. The rules are timed in seconds, not frames (`Rules::LONGEST_FRAME` caps a frame), the pile's physics steps by the seconds it is given, and the particles and tilt are timed in seconds, so nothing plays faster at 120. The cost is battery: 120 Hz refreshes the panel twice as often and draws twice the frames, so a round uses more power than at 60, which is why the system's battery saver still wins. The Records screen draws in about 10 ms, so it runs at 85 to 100 frames a second; the first Game Over and the first title after a round each take one long frame (30 to 80 ms) while their fonts are made.

**To reverse:** Remove `preferFastestRefresh()` from `onCreate`. To cap it at 90 instead, pick the fastest mode at or under 90 Hz.

## On Android, a buzz no longer holds up the frame

`MainActivity.vibrate`, which LÖVE calls on the game's thread for each pop and wrong tap, now starts the buzz on a thread of its own, one buzz after another in order.

**Why:** `Vibrator.vibrate` asks the system's vibrator service and waits for its answer: 1 to 5.5 ms a pop on the Nord, so at 120 Hz nearly every pop cost a frame. Handed to its own thread, it costs the game's thread nothing measurable, and the buzz still starts within a millisecond or two.

**To reverse:** Call `vibrator.vibrate` directly in `vibrate` again.

## The title and Game Over are laid out again only when they change

`Show#title_plan` and `#finale_plan` keep the last plan of each kind and lay out again only when the screen (`TitleScreen` or `FinaleScreen`, values) differs from the last one.

**Why:** Laying out the title measures every line at every size it tries, about 0.7 to 1 ms on the Nord, and a frame asks for the plan more than once (to draw, and for the buttons a tap or the mouse can reach). It changes only when the window, the words, or the records do.

**To reverse:** Make both methods return `screen.plan` directly.

### The splash's block cursor is one Iosevka cell, with a set gap

The maintainer's decision on setdef's mark, after three blind rounds, in em of the Iosevka Bold font size: "block cursor width: 0.50em, exactly one Iosevka cell; height: 0.95em, from 0.14em below the baseline to 0.81em above it; gap between the f and the cursor: 0.5em / 7 (about 0.0714em), counted from the end of the f's 0.5em cell." `Logotype` now gives every measure in plain ems (`BLOCK_WIDTH = 0.5`, `BLOCK_TOP = -0.81`, `BLOCK_BOTTOM = 0.14`, `BLOCK_GAP = 0.5 / 7`), measured from the f's full cell. The maintainer's blind rounds used Iosevka Bold's natural spacing (a 0.5em step per letter, no tracking), so the letters now step a full cell too, in place of the tighter 0.46em they had, and the cursor's cell starts 3.0em after the word begins. The amber is still undecided.

**Why:** Three rounds of eyeballing the artwork's x-height proportions did not settle it; plain numbers in the font's own unit can be checked and kept.

**To reverse:** Change the constants in `Logotype`; the tests state the same numbers.

## The title offers "Full screen" and Quit on a desktop

With only a mouse, a player could neither go fullscreen nor leave a fullscreen game: fullscreen has no window buttons, and the only ways were keys (F11, Alt/Cmd+Enter, Escape, Cmd+Q, Alt+F4) or B twice on a controller. On a Mac, Windows and Linux the title now has two quiet pills in the same style as How to play: "Full screen", with four corners pointing out, which in fullscreen says "Window" with the corners pointing in, and "Quit", with the power sign (IEC 5009). Both are drawn in shapes on whole device pixels, light up under the mouse, and are shown whether the game is in a window or fullscreen. "Full screen" switches exactly as F11 does (`Shell::DesktopWindow`). Quit quits at once, by a click, a tap, or the gamepad's cursor and A: a press on a labelled button is deliberate, so it asks nothing, while B keeps asking twice. The keys all stay. iPhone, iPad and Android show neither (`Presentation::NoWindowControl`): the game fills their screen already, iOS leaves quitting to the system, and Android has Back.

**Where:** a row of their own above the bottom row's right end, Quit over the speaker, so the window's controls stay together with sound and help in the corner where a desktop puts its window buttons, and never compete with Play. Where the dot-size choice takes a row above the bottom row, it goes above theirs. The row takes room from the middle of the title, which shrinks and drops lines by its usual rules. Only where even then the name, the legend and Play would not fit (windows under about 400 units tall and 1000 wide, such as the smallest, 400 × 320) are they their icons alone, round as the speaker, in the top right corner, with the name kept clear of them. The choice is made with the dot-size choice counted in, whether it shows or not, so they don't move when a round is played. `ScreenPlansTest` checks every desktop size from 400 × 320 up: everything fits, nothing overlaps, and no two buttons share a reach.

**Why:** Saffer: a control people need must be discoverable, not only a shortcut. Universal Principles of Design: give people control of their exit, and keep a control in a consistent place. Johnson: an icon plus a short label beats either alone, so the labels go only where there is truly no room. Records, Game Over, the tutorial and a round all lead back to the title by mouse alone (Back, Continue, the skip button, or the clock running out), so the title is the one place they need to be.

**To reverse:** Pass `NoWindowControl.new` to the Show everywhere in `Shell::App#load`.
