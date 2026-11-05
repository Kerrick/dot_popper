# Dot Popper

Dot Popper is a short game about patience. Dots drift and bounce around the screen, and only one of them at a time is *fresh*: bright, glossy, and worth points. Tapping the fresh dot pops it. Each pop earns a point, adds a second to the clock, and brings a new fresh dot into play. The popped dot doesn't disappear, though. It stays on screen as a dull, dark disc, and tapping it again is a mistake that costs two points and two seconds. The round starts with ten seconds on the clock and ends when the clock runs out.

What makes this hard is the order in which the dots are stacked. Popped dots stay on top, and each new fresh dot appears *underneath* all of them. As a round goes on, popped dots crowd the screen, and the fresh dot is often hidden beneath one. A tap always reaches the topmost dot under the finger, so a tap on a covered fresh dot hits the popped dot above it and costs you. The skill is waiting for the fresh dot to slide out into the open before you tap it.

Dot Popper is written in Ruby, on [Lota](https://github.com/setdef/Lota). Lota runs Ruby games on a modified build of the 2D engine from LÖVE, which is usually programmed in Lua. [Why Ruby](doc/why_ruby.md) compares this game's Ruby with the Lua a LÖVE game would use, and says where Lua is still the better choice.

## How to play

On the title screen, tap anywhere to start a round. During a round, tap or click the fresh dot whenever it is uncovered. Any mouse button works, and a press counts the moment it goes down, not when it is released. When the round ends, the game shows your score and ignores taps for a moment, so that a tap aimed at a dot in the last instant doesn't skip past it. Tap again after that to return to the title screen.

A fresh dot and a popped dot differ in more than colour. A fresh dot is light and shiny with a soft glow around it. A popped dot is dark and matte, with a crater in its centre. Because they differ in lightness and in shape, players can tell them apart in greyscale and with colour blindness.

The game also helps a new player understand a mistake. The first two times a round ends after you tapped a popped dot with the fresh one hidden under it, Game Over explains the stacking rule in two short lines, away from the action. Whenever a wrong tap happens because a fresh dot was hidden underneath, the game briefly outlines that hidden fresh dot, so you can see what you were too quick for.

When time runs out, the dots tumble to the bottom of the screen in a heap behind your score. Under the score, a line sums up the round: how many dots you popped, how many popped dots you tapped by mistake, and the longest you had to wait for a fresh dot. If the round beat one of your lifetime records, such as the most pops in a row without a wrong tap, one more line names the most impressive of them, for example "New record: 18 pops in a row without a wrong tap".

Under that line, a **Copy my result** button copies two short lines to the clipboard, ready to paste into a message: your score, whether it set or tied your best, any lifetime record the round set, and how many pops and wrong taps the round had and how long it lasted. A tap on the button only copies; a tap anywhere else continues.

### Today's goal

Once you have finished a round, the title screen also shows a goal for the day, such as "Today's goal: pop 15 bright dots in a row without tapping a popped one." A goal is met within one round. Every day has one goal, picked from a list of seven by the date, so it stays the same all day and changes at midnight. The round that first meets it says "You met today's goal!" on its Game Over screen, with a small burst of sparkles, and the title then says "Today's goal is done." The game counts how many days in a row you have met the goal. From two days on, the title says so ("You've met the daily goal 3 days in a row."). A day without it simply starts the count again, and the Records screen keeps your longest run of days.

### Your records

Once you have finished a round, the title screen shows a **Your records** button in its bottom left corner. It opens a screen with your best score and your other bests (your longest round, the most pops in a row without a wrong tap, your fastest pop, and the longest wait that still ended in a pop), your totals across every round, how many days in a row you have met the daily goal and the most you ever have, and a bar chart of your last 20 scores, with the highest of them labelled. Tap anywhere to go back to the title. Nothing on this screen affects a round.

Your bests are kept separately for each size of screen, because a small screen gets crowded sooner and is harder to score on. The game sorts screens into three sizes. Small is about the size of a phone, medium is a tablet or the desktop window as it first opens, and large is a big monitor at fullscreen. A round counts with the screen it started on, so "New best!" and "New record" only compare it with rounds on screens of the same size. The Records screen shows the bests for the screen you are using, under the heading "Your bests on screens this size", and says how big that screen is, for example "This screen is about 12 dots wide and 8 dots tall." The totals and the chart cover every round you have played, on any screen. **Copy my result** adds the same kind of line, so a friend can see what screen you played on.

### How big the dots are

Once you have finished a round, the title screen may also show a **Dot size** control with two segments, the chosen one filled. Each segment shows a small dot at the size it gives, so you can see the difference before you choose. Tap a segment to choose it:

- **Standard** is the usual game. A dot is the same size on every screen, so a phone holds fewer dots than a big monitor, gets crowded sooner, and is harder to score on. In a window you resize, the dots keep their size and a bigger window gives them more room.
- The other segment sizes the dots to this screen, and it says what that does here. On a phone it reads **Smaller, more room**. On a big monitor it reads **Bigger, less room**. In a resizable window, the dots grow and shrink with the window. Either way, every screen ends up with about the same room for dots as the desktop window, and the dots never get smaller than 60 points across, so they stay easy to tap on a phone. The size is worked out when each round starts, and if you resize the window during a round, the dots keep their size until it ends.

The control only shows where the two sizes differ by more than a tenth. On a screen about the desktop window's size, they look alike, so the control is left out, and the game keeps your choice for when you play on another screen or resize the window. The title's dots change size as soon as you switch, and the game remembers your choice. Rounds played with dots sized to the screen keep their own bests, because every screen plays about the same that way, and the Records screen says so: "Dots are sized to fit this screen, so scores compare across devices."

### Controls

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Pop a dot | Tap or click it | |
| Start a round, or continue after one | Tap or click anywhere | |
| Copy your result | **Copy my result** on the Game Over screen | |
| See your records | **Your records** on the title screen | |
| Choose how big the dots are | The **Dot size** control on the title screen | |
| Leave the Records screen | Tap or click anywhere | **Escape** |
| Turn sound on or off | The speaker button on the title screen | **M** |
| Roll the dots about on the Game Over screen | Tilt the iPad or phone, or shake it | |
| Toggle fullscreen (desktop only) | | **F11**, or **Alt+Enter** (**Cmd+Enter** on a Mac) |
| Quit (desktop only) | Close the window | **Escape**, except on the Records screen |

On a phone or tablet the game always fills the screen, and only **M**, and **Escape** on the Records screen, do anything on an attached keyboard. On Android, the Back button or gesture leaves the Records screen, leaves the app from the title screen, and does nothing during a round or at Game Over, so a stray swipe from the screen's edge never ends a round.

### Playing with a controller

Any controller your computer or iPad recognizes as a gamepad works, such as an Xbox or PlayStation controller. This needs Lota 0.1.3 or newer, which the game now uses; nobody has yet tried it with a real controller, so please report how it feels.

- The left stick or the d-pad moves a cursor around the screen.
- **A** (cross on a PlayStation controller) or the right trigger presses wherever the cursor is, exactly as a click there would.
- **Start** starts a round from the title screen, and continues after one ends.
- **Y** (triangle) copies your result on the Game Over screen.
- **X** (square) opens the Records screen from the title, once it is offered. **B** (circle) or **Start** goes back to the title from it, as does a press of **A** anywhere.
- Either shoulder button (**LB** or **RB**, or **L1** or **R1**) switches the dot size on the title screen, while it is shown.
- **Back** turns sound on or off, on every screen.
- The right stick tilts the pile of dots on the Game Over screen, so they roll the way you push it. Let go, and they fall down again.

The cursor appears when you use the controller and hides when you move the mouse or touch the screen. On an iPad, a controller paired in the iPad's Bluetooth settings works the same way, from the first iPad build made after controllers were turned on there.

### Playing with the pile

When a round ends, its dots tumble into a pile. The round is over by then, so nothing you do to them changes your score. On a phone or tablet, tilting the device rolls the dots toward whichever side is lowest, as if they were marbles in a box, and a sharp shake throws them up. A lid keeps them on the screen. Holding the device upright drops them exactly as they always fell, and on a computer without a controller they always fall straight down. For the first three rounds, a line under **Tap to continue** says how to do this. Nobody has tried it on a real iPad yet, so please report how it feels.

### Reduced motion

Setting the environment variable `DOT_POPPER_CALM=1` before starting the game turns off the screen shake that follows a mistake, and makes the dots settle gently at the end of a round instead of bouncing. Tilting the pile then turns it slowly, and shaking never throws the dots.

## Installing and running

### Without Ruby

Most players will want a packaged build, which needs no Ruby. Every tagged release from v0.1.0 to v0.5.2 is on the [Releases page](https://github.com/Kerrick/dot_popper/releases), with a Windows installer, a Windows `.zip`, and a macOS `.dmg`. The [Package workflow](https://github.com/Kerrick/dot_popper/actions/workflows/package.yml) also builds the same files on every push to `trunk`. [PACKAGING.md](PACKAGING.md) explains how the builds are made, how to install them, and how to build one yourself.

### From source

To run the game from this repository, you need Ruby 4.0.9 (the version named in `.ruby-version` and `mise.toml`) on one of these systems:

- macOS 15 or newer, on Apple silicon
- Windows x64, with Ruby from [RubyInstaller](https://rubyinstaller.org/)
- Linux x86_64

Lota isn't published on RubyGems.org, so this repository carries Lota's precompiled gems for those three systems in `vendor/cache`. `Gemfile.lock` records the SHA-256 checksum of each gem from Lota's release, and Bundler checks the gems against them. Install the gems and start the game with:

```sh
bundle install
bundle exec lota run
```

### On an iPad

An iPad version is in progress. It uses Lota's experimental iOS engine, which first shipped in Lota 0.1.3. The game has run in iPad Simulators but not yet on a real iPad. [doc/ios.md](doc/ios.md) describes what the game needs from an iOS build and how to tell whether a run went well.

## How the dot's size is chosen

Every distance and speed in the rules is measured in multiples of one number: the dot's radius, which the code calls R. Choosing R well matters, because a dot needs to be a comfortable target for a mouse and for a finger alike. The goal is a radius of 50 logical pixels under a mouse, and about 8 mm under a finger. (A logical pixel is a pixel after the operating system's display scaling; on a 2× display, each logical pixel is drawn as four physical ones.)

`conf.rb` turns on Lota's `t.highdpi` setting. With it on, Lota measures graphics in logical pixels on a desktop, and in points (on iOS) or density-independent pixels, called dp (on Android). Lota reports the display's scale as `Lota::Graphics.dpi_scale`, but neither Lota nor LÖVE can report how many pixels fit in a millimetre of the actual screen. So the game can't compute an exact 8 mm. Instead, `DotPopper::DotSize` sets R to 50 units on every system when the game starts. On a desktop that is 50 logical pixels. On a touch screen it is 50 points or dp, which measures 7.9 to 9.6 mm on current iPhones and iPads, and 7.9 mm by Android's definition of a dp. The game prints its choice when it starts.

Because R is fixed, the number of radii that fit on the screen varies from device to device, and a more crowded screen makes for a harder game. The desktop window therefore opens at 24 × 16 R (1200 × 800 logical pixels), which is about the size of an 11-inch iPad measured in radii, so that rounds on a computer and on an iPad play alike. For the same reason, bests are kept separately for small, medium, and large screens. The cut-offs, 250 and 700 square radii, are in `lib/dot_popper/rules.rb`.

A player who chooses to size the dots to the screen on the title replaces the fixed R. At the start of each round, `DotPopper::DotSize.fitted` sets R so that the field's area is 24 × 16 = 384 square radii: R = √(width × height ÷ 384). R is never under 30 units, and never over a seventh of the screen's shorter side. `DotPopper::DotSizing` holds the player's choice. [doc/decisions.md](doc/decisions.md) gives the measurements behind these choices, including the simulation of both settings.

## Running the tests

```sh
bundle exec rake test
```

The tests need no window and no graphics card, because the code is split into three layers and only the last one uses Lota:

- **The rules**, in `lib/dot_popper`, decide everything that affects the score: the dots and how they move, scoring, the clock, which dot a tap reaches, and the flow from the title screen to the end of a round. They know nothing about Lota.
- **The presentation**, in `lib/dot_popper/presentation`, decides how the game looks, sounds, and responds: easing curves, visual effects, input handling, screen layout, and the rounding of positions to whole pixels. It also knows nothing about Lota, so it is tested the same way as the rules.
- **The Lota layer**, in `lib/dot_popper/shell` and `main.rb`, carries out the presentation's decisions: it draws, plays sound, saves files, and receives input through Lota.

One test, `test/rules_fuzz_test.rb`, plays thousands of random rounds from a fixed seed and checks after every step that the rules still hold (for example, that the score never goes below zero). If it fails, it prints the seed it used; set `RULES_FUZZ_SEED` to that seed to replay the failure.

Running `bundle exec rake` with no task name runs the tests and then [Steep](https://github.com/soutaro/steep), a type checker, which checks the rules against their type signatures in `sig/`. `rake test` on its own doesn't need Steep.

`script/simulate.rb` is a design tool, not a test. It plays the real rules with a simulated player on several screen sizes, with both choices of dot size, each in its own Ractor (Ruby's unit of parallel execution). [doc/decisions.md](doc/decisions.md) reports what it found.

## Where things are

| Path | What it holds |
| --- | --- |
| `lib/dot_popper/rules.rb` | Every number in the rules: the radius, the speeds, the starting time, the rewards, and the penalties |
| `lib/dot_popper/presentation/look.rb` | Every presentation setting: the colours, durations, effect strengths, and sizes |
| `lib/dot_popper/` | The rules, as small objects, most of them immutable `Data` values |
| `lib/dot_popper/presentation/` | How the game looks, sounds, and responds, without Lota |
| `lib/dot_popper/shell/` | Drawing, sound, saving, and input, through Lota |
| `conf.rb`, `main.rb` | Lota's window settings, and the callbacks Lota calls |
| `assets/` | The font and the shaders |
| `bin/dot_popper`, `fledge.yml` | The launcher and the settings for packaged builds |
| `script/` | The icon generator, the simulator, and the Windows build check |
| `doc/` | The overnight decisions log, the iPad notes, and the case for Ruby |

## Developer settings

`main.rb` reads these environment variables. They exist for testing and for taking screenshots, and a normal launch sets none of them.

| Variable | Effect |
| --- | --- |
| `DOT_POPPER_AUTOPLAY=1` | A bot plays the game. It mostly taps fresh dots, but now and then it taps a popped dot that covers one, so that penalties appear too. It starts each round by tapping one of the title screen's dots, and copies every other result. On its second visit to the title, it opens the Records screen for three seconds first. |
| `DOT_POPPER_SHOTS=0.5,3,6.5` | Takes a screenshot at each of these times, counted in seconds of play, and saves them as `shot-1.png`, `shot-2.png`, and so on in the save folder. The game prints each file's path. |
| `DOT_POPPER_QUIT_AFTER=20` | Quits after this many seconds of play. |
| `DOT_POPPER_SEED=42` | Seeds the random number generator, so the same seed and the same taps produce the same dots. |
| `DOT_POPPER_PERF=1` | Every five seconds, prints how many frames a second the game drew and its longest single frame, measured before the game caps how much time one frame may pass to the rules. Useful for checking a new computer. |
| `DOT_POPPER_NO_SHADERS=1` | Draws plain shapes without shaders, and so without the fresh dots' glow. The game does this on its own when a shader fails to compile. |
| `DOT_POPPER_CALM=1` | Turns off screen shake and the bouncing at the end of a round (see "Reduced motion"). |
| `DOT_POPPER_FAKE_TILT=0.6,0` | Pretends to have an accelerometer that always reads this x,y, in g, along the device's portrait axes (x toward its right edge, y toward its top edge). `0.6,0` holds the device tilted to the side, so the Game Over pile rolls to the left. At Game Over the game prints where its tilt comes from: the accelerometer, the fake reading, the gamepad's right stick, or none. |
| `DOT_POPPER_WINDOW=400x850` | Opens the desktop window at this size, in logical pixels, to check how a narrow screen looks. |
| `DOT_POPPER_TODAY=2026-11-07` | Plays as if it were that date, to see that day's goal, or to build up a streak of days. |
| `DOT_POPPER_SAVE_AS=test` | Saves in a folder of this name instead of `dot_popper`, so a test run starts with no rounds played and leaves your own records alone. |

### The playtest log

Each finished round adds a line to `rounds.csv` in the game's save folder, so playtests can be compared later. The game prints the file's full path when it starts. Where the save folder is depends on how the game was started:

- Under `bundle exec lota run` on a Mac: `~/Library/Application Support/Lota/dot_popper/`
- In a packaged build: a `dot_popper` folder in the system's application-data folder, such as `%APPDATA%\dot_popper` on Windows (see [PACKAGING.md](PACKAGING.md))

The same folder also holds the game's other saved state: the best scores (`best_score.txt`), whether sound is on, how many times Game Over has explained the stacking rule (`taught.txt`), the choice of dot size (`dot_size.txt`), and the lifetime stats (`lifetime.txt`), which add up every round played on this device. `best_score.txt` and `lifetime.txt` are plain `key=value` lines, with each size of screen's bests under its name, such as `medium=24` or `small.longest_run=9`. A damaged line is ignored, and a missing file starts from nothing. Files saved by earlier versions, which kept one set of bests, give those bests to the size of the screen the game next opens on.

The first line of `rounds.csv` names the columns. When a new version of the game changes the columns, it doesn't mix old and new lines in one file: it saves the old log whole as `rounds-<date>-<time>.csv` (for example `rounds-20261105-093015.csv`) and starts a new `rounds.csv`. The columns are:

| Column | What it holds |
| --- | --- |
| `time` | When the round ended, in ISO 8601 format with the local time-zone offset |
| `seed` | The seed the round's dots were drawn from |
| `score` | The final score |
| `duration` | How many seconds the round lasted |
| `pops` | How many fresh dots were popped |
| `slips` | How many times a popped dot was tapped by mistake |
| `softened` | How many of those mistakes cost less than the full two points, because the score can't go below zero |
| `mean_wait` | The average number of seconds from a fresh dot appearing to its being popped |
| `longest_wait` | The longest of those waits |
| `goal` | The day's goal, by name and target, such as `clean_run_15` (see `DotPopper::DailyGoal::LIST`) |
| `goal_met` | `true` if this round met the day's goal, whether or not an earlier round had |

## License

Dot Popper is copyright 2026 Kerrick Long. Like Lota, it is licensed under the [AGPL-3.0-or-later](LICENSE).

The game's sounds are synthesised in code when it starts, and its icon is drawn by `script/make_icon.rb`. Both are released under [CC0-1.0](LICENSES/CC0-1.0.txt), so anyone may reuse them without conditions. The Fredoka font is by the Fredoka Project Authors, under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

Lota is an independent project. It is not made, endorsed, or supported by the LÖVE Development Team.
