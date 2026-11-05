# Decisions made overnight

The maintainer asked for a playable build by morning, and asked that only a real blocker should wait for his answer. So the agents working overnight made a number of calls on their own. This page records each one for him to review after playtesting.

Each entry says what was decided, why, and what it would take to reverse it. The entries are grouped by the part of the game they affect. A few terms recur throughout:

- **The spec** is the maintainer's description of the game's rules.
- **R** is a dot's radius. Every distance and speed in the rules is a multiple of it.
- **The field** is the area the dots move in, which is the whole window.
- **A fresh dot** is the one bright dot that can be popped for points. **A popped dot** is one already popped, which stays on screen and costs points if tapped again. A tap on a popped dot is also called a **wrong tap** or a **slip**.

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

To measure the effect, `script/simulate.rb` plays the real rules with a simulated player on several screen sizes. The simulated player waits a human reaction time, takes the time Fitts's law predicts to move to a target, waits while the fresh dot is covered, and now and then taps impatiently anyway. The two decisions below come from its results.

### The desktop window opens at 24 × 16 radii

The window opens at 1200 × 800 logical pixels, which is 24 × 16 R, shrunk if the screen is smaller. Before this decision, it filled most of the desktop.

**Why:** In the simulation, a field of that size plays like an 11-inch iPad. That means a Mac, a Windows PC, and an iPad give comparable rounds and comparable scores. The window can still be resized or made fullscreen with F11, so a player who wants a roomier, easier field can have one.

**To reverse:** Change `WINDOW` in `lib/dot_popper/presentation/look.rb`.

### Phones are much harder, and the rules don't change for them

An upright iPhone is 8 × 17 R. On that field, the simulated player scores about a quarter of what it scores on an iPad. The rules were left as they are.

**Why:** Making phones easier would need a change to the rules themselves: a radius that grows with the screen, a fixed-size play area, or time rewards scaled by the field's area. That is a design decision for the maintainer to make after playtesting, not one to make overnight.

**To reverse:** Not applicable; this is a decision not to act. Any of the three changes above would be a new rule.

### What the simulation found

These results are from 2026-11-05, with 60 rounds per device (`bundle exec ruby script/simulate.rb 60`). "Area" is the field's size in square radii, and "Penalties" counts wrong taps per round.

| Device | Area (R²) | Mean score | 90th percentile | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: |
| iPhone, portrait | 134 | 6.0 | 12 | 16.5 | 6.6 |
| 11-inch iPad | 387 | 23.6 | 35 | 34.2 | 8.8 |
| 13-inch iPad Pro | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Desktop window, 24 × 16 R | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27-inch 1440p monitor, fullscreen | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32-inch 6K monitor, fullscreen | 2035 | 76.8 | 103 | 87.6 | 7.2 |

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

The first time a player ever taps a popped dot, a hint about the stacking rule appears under the score for 2.6 seconds. The file `taught.txt` in the save folder records that it has been shown, so it never appears again. The hint is not a button, and the round carries on underneath it. On a narrow screen its two sentences stack on two lines.

**Why:** The title screen already explains the scoring, so the hint covers only the stacking, and only at the one moment a player needs it.

**To reverse:** Remove the `Tutor` from `Shell::App#load`. Deleting `taught.txt` shows the hint again.

### Game Over says what the round was made of

Under the final score, one quiet line gives three numbers: how many dots were popped, how many wrong taps there were, and the longest wait for a fresh dot. When the round didn't set a new best, the line under it says how far short of the best the score fell, instead of just showing the best.

**Why:** These are the numbers a player can act on. Wrong taps measure the impatience the game punishes, and the longest wait shows how much patience the round asked for. `RoundStats` builds the numbers from the events the rules announce. It times them with `Round#elapsed`, which counts only the time the clock was running.

**To reverse:** Stop the Game Over screen from drawing the summary line.

### Every round has its own seed, and the playtest log records it

`Game#start_round` takes a `Mode`, and the mode's seed gives the round its own random number generator. An ordinary round's seed is drawn from the game's main generator, so `DOT_POPPER_SEED` still makes a whole session repeatable. Because a round no longer shares its generator with the visual effects, a burst of droplets can't change which dots come next. Each finished round adds one line to `rounds.csv`; the README lists its columns.

**Why:** A recorded seed makes any interesting round in a playtest replayable.

**Limitation:** Lota's save folder can't append to a file, so the log is rewritten whole each time. That is fine for the few hundred lines a playtest produces.

**To reverse:** Stop subscribing the `PlaytestLog` to the game in `Shell::App#load`.

### The Daily: one shared round a day

The title screen keeps "tap anywhere to play" as the main way in, and adds a small Daily button in the bottom left, opposite the mute button. Its tappable area is at least 2 R in each direction and lies inside the screen's safe area (the part not covered by notches or system bars).

The Daily round's seed comes from the local date. `Mode.seed_for` hashes the date's digits (YYYYMMDD) with FNV-1a, a simple fixed hash; Ruby's `String#hash` can't be used, because it gives different results in different processes. Dots use random numbers only when they appear, so on the same day, the same taps give everyone the same dots. A test pins today's seed, so a future change can't quietly alter it. The day turns over at the player's local midnight, not at midnight UTC, as Wordle's does.

`DailyBest` keeps only today's best Daily score, in `daily_best.txt`. A Daily round also counts toward the all-time best score, since it is the same game. After a Daily round, the heading names the day, the best score shown is the day's, and a Share button copies two lines of text: the date and score, then the number of pops and wrong taps and the round's length. Nothing in it gives away where the day's dots go. A tap on Share only shares; a tap anywhere else continues, after the same pause as any Game Over.

**Why:** A shared daily round gives players something to compare, which is a reason to come back. The shared text includes the score, which the brief's example left out, because the score is the number players compare.

**To reverse:** Remove the Daily button from the title screen; the rest is unused without it.

### A tap on a title-screen dot pops it, but still starts the round

The title screen has seven dots drifting behind its text. The brief proposed making the title a toy: a tap on a title dot would pop it without scoring, and only a tap on empty space would start a round. Instead, a tap on a fresh title dot shows its pop (droplets, ring, and sound) and starts the round in the same instant. A tap on a popped title dot just starts the round. The title pop is scenery: it scores nothing, and its ring doesn't follow any dot in the round. The Daily and mute buttons still respond to their own taps.

**Why:** The brief's version would break the title screen's one instruction, "tap anywhere to play". With seven dots on screen, a player's first tap lands on one fairly often (about one tap in sixteen on the desktop window, more on a phone). The most inviting target, a bright dot, would then be the one place where a tap doesn't start the game. An instruction that holds only most of the time is a hidden mode, which Dan Saffer's *Microinteractions* warns against, and a player's first few seconds are when trust is easiest to lose.

**To reverse:** To get the brief's version, change `Show#tap` so that a tap on a fresh title dot calls `toy_pop` without calling `game.press`.

## Controllers

### Gamepad support is written now, and switches on with Lota 0.1.3

Lota's development branch binds `Lota::Joystick` and LÖVE's gamepad callbacks, but the game is locked to Lota 0.1.2, which has neither, and Lota 0.1.3 hasn't been released. So `main.rb` defines `gamepadpressed`, `gamepadaxis`, `joystickadded`, and `joystickremoved`, which Lota 0.1.2 never calls. `Shell::Gamepads` keeps the controllers that `joystickadded` hands it and reads only those. It never asks Lota for the list of joysticks each frame: doing so on Lota's development branch created new joystick objects that could be freed while still in use, and on iOS, where SDL presents the accelerometer as a joystick, that crashed the game. For a while phones and tablets took no controllers at all, but now that the game no longer asks for the list, and Lota has fixed the cause, a controller paired with an iPad is accepted too. `Shell::Gamepads` keeps only joysticks that are gamepads, so an iPad's accelerometer, which SDL also presents as a joystick, is never one.

**Why:** Writing the support now means that moving the Gemfile to Lota 0.1.3 is the whole upgrade.

**Not yet checked:** Nothing has run with a real controller, nor with the virtual joystick in Lota's development build, because the test build available that night predated the joystick bindings.

**To reverse:** Remove the four gamepad callbacks from `main.rb`.

### A controller aims a cursor and presses where it points, like a click

**A** presses at the cursor's position, on the frame the button goes down, through the same path a mouse press takes (`InputRouter#gamepad_pressed`, then `Show#tap`). So the mute, Daily, and Share buttons, the title-screen pop, and the choice of which dot a press reaches all work exactly as they do for a mouse. The right trigger acts as a second **A**. It presses once when pulled past halfway, and can press again only after it has been released below 0.3, so a trigger resting near the halfway point can't press twice.

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

### Start and Y are shortcuts on the menus, never during play

On the title screen, **Start** starts an ordinary round (without popping a title dot). On the Game Over screen, it continues, after the same pause as a tap. During a round it does nothing, because only a press at a position may affect the score. **Y** acts as the Daily button on the title screen and as Share after a Daily round, and does nothing elsewhere. **Back** turns sound on or off, as **M** does.

**Why:** A button that scored without aiming would bypass the game.

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
