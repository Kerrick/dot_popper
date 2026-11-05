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

### A window resized during a round keeps every dot on screen

When the window changes size mid-round, the round in progress switches to the new field, and any dot left outside it is moved to the field's edge. The next round starts on the new field as usual. The same happens when a tablet is rotated, and the heap of dots at the end of a round is refitted the same way.

**Why:** The spec sizes the field when the game starts and doesn't mention resizing. Leaving dots outside the window would make them impossible to tap, and freezing the old size would leave part of the window empty.

**To reverse:** Change `Game#field=` (which `Shell::App#resize` calls) to keep the old field until the next round.

### The Game Over screen ignores taps for 0.9 seconds

For 0.9 seconds after time runs out, the Game Over screen ignores presses. The constant is `Rules::GAME_OVER_GRACE`.

**Why:** A player often taps at a dot in the round's final instant. Without the pause, that tap would dismiss the final score before the player had seen it. The spec asks for the flow between screens to feel natural, and this is the only timing rule added for that reason.

**To reverse:** Set `GAME_OVER_GRACE` to 0.

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

Once a round has been played, the title shows a button in its bottom row (on an upright phone, in a row of its own just above). It reads "Dots: same size everywhere" or "Dots: sized to your screen", and a tap switches between the two. The title's dots and its best score change at once to match. Either shoulder button on a controller does the same. The choice is saved in `dot_size.txt` in the save folder.

- **Same size everywhere** is the default, and it is exactly the spec's rule: R is `DotSize.for(os)`, 50 units on every system.
- **Sized to your screen** sets R when each round starts, to the radius that gives the field an area of 24 × 16 = 384 square radii, the desktop window's area: R = √(field area ÷ 384). R is never smaller than 30 units, so a dot is 60 points across, comfortably over Apple's 44-point smallest touch target. It is never larger than a seventh of the screen's shorter side, so that on a long, thin window a dot stays a dot. The numbers are `FITTED_AREA`, `SMALLEST_FITTED_RADIUS`, and `LARGEST_FITTED_SHARE` in `rules.rb`, and `DotSize.fitted` and `DotSizing` apply them.

A round keeps its radius until it ends. If the window is resized during a round, the dots are kept on screen but stay the same size, and the next round works out its radius again. Speeds are still in radii per second, so they scale with R. Rings, droplets, and floating numbers scale with the round's dots too. Buttons and their tap areas don't change, because they are sized for a finger, not for the field. Because every screen is about equally crowded with this choice, its rounds keep bests of their own (`SizeClass::FITTED`, shown as "Your bests with dots sized to the screen"), apart from the small, medium, and large classes. The Records screen explains the choice in one line, and a shared result says "Played with the dots sized to my screen."

The words never call either choice easy or hard. They say what each choice does.

**Why:** The simulation (below) shows the screen deciding the difficulty: the same model player averages 6 points on an upright phone and 77 on a 6K monitor. That works against several ideas the game is built on:

- Juul (*The Art of Failure*) argues that failure is worth enjoying only when the player can blame it on themselves. A phone player who loses to a crowded screen they didn't choose can't.
- Garfield (*Characteristics of Games*) separates luck and skill, which players can see, from a handicap that is hidden. Screen size is a hidden handicap: nothing tells the player it is there.
- Koster (*A Theory of Fun*) says the challenge must be calibrated. With R fixed, a phone starts its difficulty curve far above a monitor's.
- Nguyen (*Games: Agency as Art*) describes games as chosen constraints. Making the field's size a setting the player picks turns an accident of hardware into one of those choices.
- Sylvester (*Designing Games*) favours one rule that works at both ends of a range over special cases. One formula fits a phone and a 6K monitor alike, with no table of devices.

The spec's rule stays the default, and it changes only when the player chooses. The setting is a choice rather than the new rule because R is meant as a physical size, and some players will prefer dots that feel the same everywhere.

**To reverse:** Remove the button from `TitlePainter` and the tap from `Show#tap`, and delete `dot_size.txt`. With the saved choice gone, `DotSizing.parse` returns `SAME_EVERYWHERE`, which is the spec's rule. The fitted bests stay in the saved files but are no longer shown.

### What the simulation found

These results are from 2026-11-05, with 60 rounds per device for each choice of dot size (`bundle exec ruby script/simulate.rb 60`). "R" is the radius in graphics units, "Area" is the field's size in square radii, and "Penalties" counts wrong taps per round.

With dots the same size everywhere (the default, and the spec's rule):

| Device | R | Area (R²) | Mean score | 90th percentile | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 50 | 134 | 6.0 | 12 | 16.5 | 6.6 |
| 11-inch iPad | 50 | 387 | 23.6 | 35 | 34.2 | 8.8 |
| 13-inch iPad Pro | 50 | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Desktop window, 24 × 16 R | 50 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, fullscreen | 50 | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32-inch 6K monitor, fullscreen | 50 | 2035 | 76.8 | 103 | 87.6 | 7.2 |

With dots sized to the screen:

| Device | R | Area (R²) | Mean score | 90th percentile | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 30.0 | 373 | 21.6 | 33 | 32.2 | 8.6 |
| 11-inch iPad | 50.2 | 384 | 22.2 | 33 | 32.8 | 8.8 |
| 13-inch iPad Pro | 60.7 | 384 | 23.0 | 33 | 33.6 | 8.7 |
| Desktop window, 24 × 16 R | 50.0 | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, fullscreen | 98.0 | 384 | 23.6 | 35 | 34.2 | 7.3 |
| 32-inch 6K monitor, fullscreen | 115.1 | 384 | 20.3 | 31 | 31.1 | 7.2 |

Sized to the screen, the mean scores fall between 20.3 and 23.6, within 8% of their average of 21.9. With the same size everywhere they run from 6.0 to 76.8, nearly thirteen times apart. On the phone, the smallest radius applies: the exact fit would be 29.6, so its field is 373 R² rather than 384, a little more crowded than the others, though its score is still within the range. The rest of the spread follows the screens' shapes and the model player's luck, not their size.

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

The glow is off when shaders are off, when a canvas can't be made, or when `BLOOM.strength` in `look.rb` is 0.

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

The stick has a circular dead zone of 0.2, because worn sticks can drift up to about 0.15 when left alone. Beyond the dead zone, the cursor's speed is the square of the push, up to 16 R per second at full tilt (`GAMEPAD` in `look.rb`). At full speed it crosses the 24 R desktop window in 1.5 seconds, nearly three times the speed of the fastest dot. At half tilt it moves at a quarter of that speed, for fine aiming. A diagonal on the d-pad moves no faster than a straight direction.

The stick is read every frame, rather than through axis-change events, so that a change of window focus can't leave the cursor stuck moving. When several gamepads are connected, their pushes add together.

**Why:** A player needs to cross the screen quickly and also to settle precisely on a dot.

**To reverse:** Adjust `dead_zone`, `curve`, and `speed` in `GAMEPAD`.

### The cursor appears only for a controller

Any gamepad button, or a push on the stick beyond the dead zone, shows the cursor. Moving the mouse, clicking, or touching the screen hides it. While hidden, it waits where the mouse is, so a player who picks up the controller starts from there. Pressing **A** while the cursor is hidden still presses where it is waiting.

The cursor is a thin cream ring with four short ticks and a dot in the centre, each with a dark edge so it shows on any background. It is open in the middle so it never hides the dot it is over, and it is drawn on top of everything, aligned to whole pixels.

**Why:** A mouse player doesn't need a second pointer on screen. Making the first **A** press only reveal the cursor would mean the game ignored a press, which feels broken.

**To reverse:** Remove the `hide` calls in `Shell::App`'s mouse and touch handlers.

### Start, Y, X, and B are shortcuts on the menus, never during play

On the title screen, **Start** starts an ordinary round (without popping a title dot). On the Game Over screen, it continues, after the same pause as a tap. During a round it does nothing, because only a press at a position may affect the score. **Y** copies the result on the Game Over screen, as the Copy my result button does, and does nothing elsewhere. **Back** turns sound on or off, as **M** does.

**Why:** A button that scored without aiming would bypass the game.

The Records screen added three more. **X** opens it from the title, once it is offered, so a controller player needn't steer the cursor to the corner. **B**, the usual "go back" button, leaves it, and so does **Start**, which on every other menu screen means "go on". **A** works as a tap anywhere, which also leaves it. **Back** stays the sound toggle on every screen, including this one, so one button never means two things. B and X do nothing during a round, for the same reason Start doesn't. Either shoulder button switches the title's dot-size choice once it is offered, because shoulder buttons usually switch between options, and both were free.

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
- older dots stay above newer ones.

A second test drives the whole `Game` through its screens and checks that nothing outside a running round touches the score or the clock. The fuzz test needs no extra gem and runs in under a second. When it fails, it prints its seed, and setting `RULES_FUZZ_SEED` to that seed replays the failure. Deliberately reversing `Stack#top_at` or `Stack#slide_under` makes it fail at once.

**Why:** Hand-written tests cover the cases someone thought of; random play finds the ones nobody did.

**To reverse:** Delete the test file.

### doc/why_ruby.md argues for Ruby with this game's code, and gives Lua its due

[Why Ruby](why_ruby.md) puts each claim beside the code in this game that demonstrates it, and beside the idiomatic LÖVE Lua it replaces. Its numbers were measured that night on the maintainer's Mac. Moving thirty dots 100,000 times took 4.4 seconds in Ruby (3.4 seconds with YJIT, Ruby's just-in-time compiler), 0.58 seconds in Lua 5.4, and 0.012 seconds in LuaJIT, all ending with identical dot positions.

**Why:** A showcase for Ruby is more convincing when it is honest about where Lua is faster.

**To reverse:** Not applicable; it is a document.

### The Game Over pile is a toy that tilts and shakes

At Game Over, tilting a phone or tablet turns the pile's gravity toward the lowest side of the screen, and a sharp shake throws every dot up, against the pull. With a gamepad, the right stick turns it instead: the dots fall the way it points, and straight down when it is let go. While the pile is tilted, a lid along the top of the window keeps the dots on the screen. The accelerometer is switched on only while the pile exists. A light line under "Tap to continue" says how to do it on the first three Game Overs: "Tilt your iPad to roll the dots.", or "Push the right stick to roll the dots." with a controller. With no accelerometer and no controller, the pile is unchanged.

The math lives in `presentation/tilt.rb` and is tested. SDL reports the accelerometer in the device's own portrait axes, as the push holding the device up, and never turns those axes with the screen, so the game maps each of the four display orientations itself. The reading is smoothed with a time constant of 0.2 seconds, so a hand's tremor never reaches the dots. One g is the pile's existing gravity, so holding the device upright drops the dots exactly as before. A shake is a jump of more than 1.2 g away from the last 0.3 seconds' average, followed by a 0.6-second cooldown. With `DOT_POPPER_CALM=1`, the pull changes four times as slowly and a shake never throws anything. `DOT_POPPER_FAKE_TILT=x,y` stands in for an accelerometer during testing.

**Why:** Jesse Schell's lens of the toy asks whether something is fun to play with even when there is no goal. Once the round ends, its dots no longer affect anything, which makes them a free toy, and handling the device is the most natural way to play with them. Players linger and play with the dots after the game, instead of leaving the moment the score appears. Since the rules are frozen by then, none of this can touch fairness.

**To reverse:** In `Shell::App#load`, stop creating and subscribing `Tilting`, and stop passing it to the `Renderer`. The pile then falls straight down and the hint never shows. Deleting `presentation/tilt.rb`, `shell/tilting.rb`, `shell/accelerometer.rb`, and `shell/tilt_hint_painter.rb`, along with `Look::TILT`, removes the feature entirely.

### The stacking rule is taught on Game Over, not in play

The hint that explains the stacking rule no longer appears during a round. It appears on Game Over instead, after a round in which the player tapped a popped dot while the bright dot was hidden underneath it. It shows on the first two such Game Overs and never again. The note is two short lines between the score pill and "Time's up!", which moves down a little to make room: "New dots appear under the popped ones. Wait for the bright dot to slide out, then tap it." On a narrow screen, a line that would not fit is broken evenly. `taught.txt` now counts how many times the note has shown. A player whose file says `taught`, from an older version, already saw the hint, so it does not show again. In play, the dashed outline of the hidden bright dot is unchanged.

**Why:** Players don't read during intense action (Johnson, Hodent), so a sentence that appeared mid-round mostly went unread and covered the field. A penalty is also the wrong trigger for reading (Saffer). Game Over is calm, and it follows the mistake closely enough that the note still makes sense. Showing it only after a mistake caused by a hidden dot means it explains something the player just saw. Showing it twice gives a player who taps through quickly a second chance.

**To reverse:** Pass `lesson: nil` to the `Finale` in `Show#round_ended`. Setting `Look::LESSON.times` changes how often the note shows.

### The dot-size choice is a labelled segmented control

The title's dot-size choice used to be a single pill that read "Dots: same size everywhere" and switched when tapped. It is now a small control labelled "Dot size", with two segments side by side: "Same everywhere" and "Fit the screen". The chosen segment is filled in cream with dark text. Tapping a segment chooses it, and tapping the chosen one again changes nothing. Either shoulder button on a controller still switches between the two. On a wide window the control sits in the bottom row between "Your records" and the mute button, with its label on the left and its segments centred on the screen. On an upright phone it takes a row of its own above them, with the label above the segments. Each segment is a button's height (at least 44 units), and a tap reaches it within a dot's width, as for the other title buttons.

**Why:** A toggle should show its options and which one is chosen (Tidwell). A single pill showed only the current state, so it didn't say that tapping it would switch, or what the other choice was. Naming the choice "Dot size" and each option by what it does makes the control read as a setting rather than a statement (Podmajersky).

**To reverse:** In `TitlePainter#draw`, draw a `PillButton` at `layout.sizing_control.frame` instead of the `SegmentedPainter`, and have `Show#tap` call `toggle_sizing` on that frame's reach.

### The Records screen keeps labels near their numbers

The rows' type is a little larger (23 units at a layout scale of 1, up from 20). Each column is only as wide as its longest row needs, measured at that size, so the columns no longer stretch to fill a wide window. Two columns stand side by side only when both fit at that width; otherwise everything stacks in one centred column. A faint dotted leader runs from each label to its number. The two dense sentences under the heading are now one short line, "This screen is about 12 dots wide and 8 dots tall." With **Fit the screen** chosen, a second line follows: "Dots fit the screen, so scores compare across devices."

**Why:** Proximity groups things (Johnson, Tidwell). On a wide window, the old columns put a label like "Best score" half the screen away from its number, so the eye could lose the row. The second sentence explained a setting from a screen where it can't be changed. Now the title's segmented control names both choices, so Records only needs to say what the current choice means.

**To reverse:** Pass `widest: nil` to `RecordsLayout` in `RecordsPainter#draw`, drop `leader`, and restore `Look::RECORDS.text` to 20.
