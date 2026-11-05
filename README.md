# Dot Popper

Dot Popper is a short game about patience. Dots drift and bounce around the screen, and only one of them at a time is *fresh*: bright, glossy, and worth points. Tapping the fresh dot pops it. Each pop earns a point, adds a second to the clock, and brings a new fresh dot into play. The popped dot doesn't disappear, though. It stays on screen as a dull, dark disc, and tapping it again is a mistake that costs two points and two seconds. The round starts with ten seconds on the clock and ends when the clock runs out.

What makes this hard is the order in which the dots are stacked. Popped dots stay on top, and each new fresh dot appears *underneath* all of them. As a round goes on, popped dots crowd the screen, and the fresh dot is often hidden beneath one. A tap always reaches the topmost dot under the finger, so a tap on a covered fresh dot hits the popped dot above it and costs you. The skill is waiting for the fresh dot to slide out into the open before you tap it.

Dot Popper is written in Ruby, on [Lota](https://github.com/setdef/Lota). Lota runs Ruby games on a modified build of the 2D engine from LÖVE, which is usually programmed in Lua. [Why Ruby](doc/why_ruby.md) compares this game's Ruby with the Lua a LÖVE game would use, and says where Lua is still the better choice.

## How to play

On the title screen, tap anywhere to start a round. During a round, tap or click the fresh dot whenever it is uncovered. Any mouse button works, and a press counts the moment it goes down, not when it is released. When the round ends, the game shows your score and ignores taps for a moment, so that a tap aimed at a dot in the last instant doesn't skip past it. Tap again after that to return to the title screen.

A fresh dot and a popped dot differ in more than colour. A fresh dot is light and shiny with a soft glow around it. A popped dot is dark and matte, with a crater in its centre. Because they differ in lightness and in shape, players can tell them apart in greyscale and with colour blindness.

The game also helps a new player understand a mistake. The first time you ever tap a popped dot, a one-line hint under the score explains the stacking rule, and it never appears again. Whenever a wrong tap happens because a fresh dot was hidden underneath, the game briefly outlines that hidden fresh dot, so you can see what you were too quick for.

When time runs out, the dots tumble to the bottom of the screen in a heap behind your score. Under the score, a line sums up the round: how many dots you popped, how many popped dots you tapped by mistake, and the longest you had to wait for a fresh dot. If the round beat one of your lifetime records, such as the most pops in a row without a wrong tap, one more line names the most impressive of them, for example "New record: 18 pops in a row without a wrong tap".

Under that line, a **Copy my result** button copies two short lines to the clipboard, ready to paste into a message: your score, whether it set or tied your best, any lifetime record the round set, and how many pops and wrong taps the round had and how long it lasted. A tap on the button only copies; a tap anywhere else continues.

### Your records

Once you have finished a round, the title screen shows a **Your records** button in its bottom left corner. It opens a screen with your best score and your other bests (your longest round, the most pops in a row without a wrong tap, your fastest pop, and the longest wait that still ended in a pop), your totals across every round, and a bar chart of your last 20 scores, with the highest of them labelled. Tap anywhere to go back to the title. Nothing on this screen affects a round.

### Controls

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Pop a dot | Tap or click it | |
| Start a round, or continue after one | Tap or click anywhere | |
| Copy your result | **Copy my result** on the Game Over screen | |
| See your records | **Your records** on the title screen | |
| Leave the Records screen | Tap or click anywhere | **Escape** |
| Turn sound on or off | The speaker button on the title screen | **M** |
| Toggle fullscreen (desktop only) | | **F11**, or **Alt+Enter** (**Cmd+Enter** on a Mac) |
| Quit (desktop only) | Close the window | **Escape**, except on the Records screen |

On a phone or tablet the game always fills the screen and never quits itself, so only **M**, and **Escape** on the Records screen, do anything on an attached keyboard.

### Playing with a controller

The game has gamepad support written and tested, but it can't be used yet. It needs Lota 0.1.3, which hasn't been released; this version of Dot Popper uses Lota 0.1.2, which doesn't report controllers to the game at all. Once the game moves to Lota 0.1.3, a controller will work like this:

- The left stick or the d-pad moves a cursor around the screen.
- **A** (cross on a PlayStation controller) or the right trigger presses wherever the cursor is, exactly as a click there would.
- **Start** starts a round from the title screen, and continues after one ends.
- **Y** (triangle) copies your result on the Game Over screen.
- **Back** turns sound on or off.

The cursor appears when you use the controller and hides when you move the mouse or touch the screen. An iPad build, which runs on Lota's development engine rather than 0.1.2, should accept a controller paired with the iPad in the same way, but nobody has tried one yet, and the current iPad kit was built before this was turned on.

### Reduced motion

Setting the environment variable `DOT_POPPER_CALM=1` before starting the game turns off the screen shake that follows a mistake, and makes the dots settle gently at the end of a round instead of bouncing.

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

An iPad version is in progress. It uses Lota's experimental iOS engine, which isn't part of Lota 0.1.2. The game has run in iPad Simulators but not yet on a real iPad. [doc/ios.md](doc/ios.md) describes what the game needs from an iOS build and how to tell whether a run went well.

## How the dot's size is chosen

Every distance and speed in the rules is measured in multiples of one number: the dot's radius, which the code calls R. Choosing R well matters, because a dot needs to be a comfortable target for a mouse and for a finger alike. The goal is a radius of 50 logical pixels under a mouse, and about 8 mm under a finger. (A logical pixel is a pixel after the operating system's display scaling; on a 2× display, each logical pixel is drawn as four physical ones.)

`conf.rb` turns on Lota's `t.highdpi` setting. With it on, Lota measures graphics in logical pixels on a desktop, and in points (on iOS) or density-independent pixels, called dp (on Android). Lota reports the display's scale as `Lota::Graphics.dpi_scale`, but neither Lota nor LÖVE can report how many pixels fit in a millimetre of the actual screen. So the game can't compute an exact 8 mm. Instead, `DotPopper::DotSize` sets R to 50 units on every system when the game starts. On a desktop that is 50 logical pixels. On a touch screen it is 50 points or dp, which measures 7.9 to 9.6 mm on current iPhones and iPads, and 7.9 mm by Android's definition of a dp. The game prints its choice when it starts.

Because R is fixed, the number of radii that fit on the screen varies from device to device, and a more crowded screen makes for a harder game. The desktop window therefore opens at 24 × 16 R (1200 × 800 logical pixels), which is about the size of an 11-inch iPad measured in radii, so that rounds on a computer and on an iPad play alike. [doc/decisions.md](doc/decisions.md) gives the measurements behind this choice.

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

`script/simulate.rb` is a design tool, not a test. It plays the real rules with a simulated player on several screen sizes at once, each in its own Ractor (Ruby's unit of parallel execution). [doc/decisions.md](doc/decisions.md) reports what it found.

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
| `DOT_POPPER_NO_SHADERS=1` | Draws plain shapes without shaders, and so without the fresh dots' glow. The game does this on its own when a shader fails to compile. |
| `DOT_POPPER_CALM=1` | Turns off screen shake and the bouncing at the end of a round (see "Reduced motion"). |
| `DOT_POPPER_WINDOW=400x850` | Opens the desktop window at this size, in logical pixels, to check how a narrow screen looks. |
| `DOT_POPPER_SAVE_AS=test` | Saves in a folder of this name instead of `dot_popper`, so a test run starts with no rounds played and leaves your own records alone. |

### The playtest log

Each finished round adds a line to `rounds.csv` in the game's save folder, so playtests can be compared later. The game prints the file's full path when it starts. Where the save folder is depends on how the game was started:

- Under `bundle exec lota run` on a Mac: `~/Library/Application Support/Lota/dot_popper/`
- In a packaged build: a `dot_popper` folder in the system's application-data folder, such as `%APPDATA%\dot_popper` on Windows (see [PACKAGING.md](PACKAGING.md))

The same folder also holds the game's other saved state: the best score (`best_score.txt`), whether sound is on, whether the first-mistake hint has been shown, and the lifetime stats (`lifetime.txt`), which add up every round played on this device. `lifetime.txt` is plain `key=value` lines; a damaged line is ignored, and a missing file starts the stats from nothing.

The first line of `rounds.csv` names the columns:

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

## License

Dot Popper is copyright 2026 Kerrick Long. Like Lota, it is licensed under the [AGPL-3.0-or-later](LICENSE).

The game's sounds are synthesised in code when it starts, and its icon is drawn by `script/make_icon.rb`. Both are released under [CC0-1.0](LICENSES/CC0-1.0.txt), so anyone may reuse them without conditions. The Fredoka font is by the Fredoka Project Authors, under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

Lota is an independent project. It is not made, endorsed, or supported by the LÖVE Development Team.
