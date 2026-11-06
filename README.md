# Dot Popper

Dot Popper is a short game about patience. Dots drift and bounce around the screen, and only one of them at a time is *fresh*: bright, glossy, and worth points. Tapping the fresh dot pops it. Each pop earns a point, adds a second to the clock, and brings a new fresh dot into play. The popped dot doesn't disappear, though. It stays on screen as a dull, dark disc, and tapping it again is a mistake that costs two points and two seconds. The round starts with ten seconds on the clock and ends when the clock runs out.

What makes this hard is the order in which the dots are stacked. Popped dots stay on top, and each new fresh dot appears *underneath* all of them. As a round goes on, popped dots crowd the screen, and the fresh dot is often hidden beneath one. A tap always reaches the topmost dot under the finger, so a tap on a covered fresh dot hits the popped dot above it and costs you. The skill is waiting for the fresh dot to slide out into the open before you tap it. A new fresh dot appears at a random place, but if no fingertip-sized part of it would come out from under the popped dots within a second, the game picks again.

Dot Popper is written in Ruby, on [Lota](https://github.com/setdef/Lota). Lota runs Ruby games on a modified build of the 2D engine from LÖVE, which is usually programmed in Lua. [Why Ruby](doc/why_ruby.md) compares this game's Ruby with the Lua a LÖVE game would use, and says where Lua is still the better choice.

## How to play

On the title screen, tap **Play** to start a round. During a round, tap or click the fresh dot whenever it is uncovered. Any mouse button works, and a press counts the moment it goes down, not when it is released. When the round ends, the game shows your score and a **Continue** button, which ignores taps for a moment, so that a tap aimed at a dot in the last instant doesn't skip past the score. Tap **Continue** after that to return to the title screen. Outside a round, a tap away from the buttons does nothing, except to play with the dots: on the title, a tap on a bright dot pops it for fun, and at Game Over the dots are yours to drag about (see "Playing with the pile").

A fresh dot and a popped dot differ in more than colour. A fresh dot is light and shiny, with a thin bright rim at its edge, which is exactly where a tap reaches it. A popped dot is dark and matte, with a crater in its centre. Because they differ in lightness and in shape, players can tell them apart in greyscale and with colour blindness.

The game also helps a new player understand a mistake. The first two times a round ends after you tapped a popped dot with the fresh one hidden under it, Game Over explains the stacking rule in two short lines, away from the action. Whenever a wrong tap happens because a fresh dot was hidden underneath, the game briefly outlines that hidden fresh dot, so you can see what you were too quick for.

When time runs out, the dots tumble to the bottom of the screen in a heap behind your score. Under the score, a line sums up the round: how many dots you popped, how many popped dots you tapped by mistake, and the longest you had to wait for a fresh dot. If the round beat one of your lifetime records, such as the most pops in a row without a wrong tap, one more line names the most impressive of them, for example "New record: 18 pops in a row without a wrong tap".

Under **Continue**, a **Copy my result** button copies two short lines to the clipboard, ready to paste into a message: your score, whether it set or tied your best, any lifetime record the round set, and how many pops and wrong taps the round had and how long it lasted. A tap on it only copies.

### Today's goal

Once you have finished a round, the title screen also shows a goal for the day, such as "Today's goal: pop 15 bright dots in a row without tapping a popped one." A goal is met within one round. Every day has one goal, picked from a list of seven by the date, so it stays the same all day and changes at midnight. The round that first meets it says "You met today's goal!" on its Game Over screen, with a small burst of sparkles, and the title then says "Today's goal is done." The game counts how many days in a row you have met the goal. From two days on, the title says so ("You've met the daily goal 3 days in a row."). A day without it simply starts the count again, and the Records screen keeps your longest run of days.

### Your records

Once you have finished a round, the title screen shows a **Your records** button in its bottom left corner. It opens a screen with your best score and your other bests (your longest round, the most pops in a row without a wrong tap, your fastest pop, and the longest wait that still ended in a pop), your totals across every round, how many days in a row you have met the daily goal and the most you ever have, and a bar chart of your last 20 scores, with the highest that counts toward the bests shown labelled. **Back**, in the bottom left corner, goes back to the title. **Credits**, beside it (above it on a narrow phone), opens who made the game, its license, and the licenses of what it is made with: Fredoka's and Iosevka's (which sets the license texts in monospace) and, when the app carries them, the notices of Lota and of Fledge, which a store app's player cannot otherwise open as files. Scroll them with the mouse wheel, a finger's drag, the arrow, Page Up, Page Down, Home and End keys, or a gamepad's left stick or d-pad; **Back** (or **Escape**, or **B**) returns to the records. Nothing on these screens affects a round.

To start your records again, press and hold **Clear my records…** in the screen's bottom right corner for two seconds. While you hold it, the screen says what will go: your bests, totals, chart, and goal streak (with today's goal counted as not yet met). Let go sooner and nothing changes. Once they are cleared, the screen shows "Records cleared." with an **Undo** button for ten seconds, which puts everything back exactly as it was. Playing a round ends the chance to undo. Clearing keeps your settings (sound and dot size), the playtest log, and how often the game has explained the stacking rule and the pile. Afterward the title shows no best score or daily goal until you finish another round, as for a new player, but it keeps **Your records** and the dot-size choice.

With dots that fit the screen, every screen plays about the same, so their rounds share one set of bests, and the Records screen shows them under "Your bests with dots sized to the screen". With **Standard** dots (see "How big the dots are"), your bests are kept separately for each size of screen, because a small screen gets crowded sooner and is harder to score on. The game sorts screens into three sizes. Small is about the size of a phone, medium is a tablet or the desktop window as it first opens, and large is a big monitor at fullscreen. A round counts with the screen it started on, so "New best!" and "New record" only compare it with rounds on screens of the same size. The first round you play on a new size of screen has nothing to beat, so it sets your best there without being called a new best; Game Over just shows "Your best: 18". The Records screen shows the bests for the screen you are using, under the heading "Your bests with standard dots on screens this size", and says how big that screen is, for example "This screen is about 12 dots wide and 8 dots tall." The totals and the chart cover every round you have played, on any screen, but the chart's bars for rounds that don't count toward the bests shown are dimmed, and a line under it says which rounds the brighter bars are. **Copy my result** adds the same kind of line, so a friend can see what screen you played on.

### How big the dots are

The dots are sized to fit the screen, so every screen, from a phone to a big monitor, has about the same room for dots as the desktop window, and plays about as hard. The dots never get smaller than 60 points across, so they stay easy to tap on a phone. The size is worked out when each round starts, and if you resize the window or turn the phone during a round, the dots keep their size until it ends. Each dot stays as far across and down the screen as it was, so turning a phone and back puts the dots back where they were.

Once you have finished a round, the title screen may also show a **Dot size** control with two segments, the chosen one filled. Each is named for what it does on this screen, next to the other: **Smaller** (with **More room** under it) or **Bigger** (with **Less room**), with a small dot at the size it gives, so you can see the difference before you choose. Tap a segment to choose it:

- The default fits the dots to the screen, the usual game as described above. On a phone it is the **Smaller** one, and on a big monitor the **Bigger** one. In a resizable window, the dots grow and shrink with the window.
- The other is the spec's fixed size: a dot is the same size on every screen, with a radius of 50 points (or logical pixels on a computer). So a phone holds fewer dots than a big monitor, gets crowded sooner, and is harder to score on, but its dots are bigger to hit. In a window you resize, the dots keep their size and a bigger window gives them more room.

Choosing never moves the Play button. A player who never chose plays with dots that fit the screen. One who chose the fixed size keeps it.

The control only shows where the two sizes differ by more than a tenth. On a screen about the desktop window's size, they look alike, so the control is left out, and the game keeps your choice for when you play on another screen or resize the window. The title's dots change size as soon as you switch, and the game remembers your choice. The Records screen says what fitting the dots means: "Dots are sized to fit this screen, so scores compare across devices."

### Controls

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Pop a dot | Tap or click it | |
| Start a round, or continue after one | **Play** on the title, **Continue** at Game Over | **Enter** or **Space** (and **Escape** at Game Over) |
| Copy your result | **Copy my result** on the Game Over screen | |
| See your records | **Your records** on the title screen | |
| Choose how big the dots are | The **Dot size** control on the title screen | |
| Leave the Records screen | **Back** | **Escape**, **Enter** or **Space** |
| Read the credits and licenses | **Credits** on the Records screen | **C** on the Records screen |
| Clear your records | Hold **Clear my records…** on the Records screen for two seconds | |
| Turn sound on or off | The speaker button on the title screen | **M** |
| Roll the dots about on the Game Over screen | Tilt the iPad or phone, or shake it | |
| Throw a dot about on the Game Over screen | Drag it with a finger or the mouse, and let go | |
| Toggle fullscreen (desktop only) | | **F11**, or **Alt+Enter** (**Cmd+Enter** on a Mac) |
| Quit (desktop only) | Close the window | **Escape** on the title screen |

The words on screen follow whatever you last played with. With a finger they say "Tap", with a mouse they say "Click", and with a controller the buttons name the controller's button that presses them ("Play (A)"). A phone or tablet starts out saying "Tap", and a computer starts out saying "Click".

On a phone or tablet the game always fills the screen, and only **M**, **Enter** and **Space**, and **Escape** on the Records screen and at Game Over, do anything on an attached keyboard. On Android, the Back button or gesture leaves the Records screen, goes on from Game Over to the title, leaves the app from the title screen, and does nothing during a round, so a stray swipe from the screen's edge never ends a round.

### Playing with a controller

Any controller your computer or iPad recognizes as a gamepad works, such as an Xbox or PlayStation controller, and an Xbox Elite controller's back paddles work when they are mapped to **A**. This needs Lota 0.1.3 or newer, which the game uses.

- The left stick or the d-pad moves a cursor around the screen. At full tilt it crosses the window from corner to corner in about a second, however big the window is, and it takes about a third of a second to get up to that speed. A gentle tilt moves it slowly, for aiming, and letting go stops it at once.
- **A** (cross on a PlayStation controller) or the right trigger presses wherever the cursor is, exactly as a click there would. With the cursor on no button, outside a round, it presses the screen's main button: **Play**, **Continue**, or **Back**.
- **Start** starts a round from the title screen, and continues after one ends.
- **Y** (triangle) copies your result on the Game Over screen. On the Records screen, holding **Y** for two seconds clears your records (as does holding **A** with the cursor on **Clear my records…**), and a press of **Y** while **Undo** shows undoes it.
- **X** (square) opens the Records screen from the title, once it is offered, and on the Records screen opens the credits, where the left stick and d-pad scroll and **B** goes back. **B** (circle) or **Start** goes back to the title from it, as does **A** on **Back** or on no button. **B** also goes on from Game Over. On the title, **B** shows "Press B again to quit", and a second **B** within two seconds quits the game (except on iPhone and iPad, where apps are left from the system).
- Either shoulder button (**LB** or **RB**, or **L1** or **R1**) switches the dot size on the title screen, while it is shown.
- **Back** turns sound on or off, on every screen.
- On the Game Over screen, holding **A** on a dot picks it up. Move the cursor to drag the dot, and let go of **A** to throw it. A quick press of **A** that drags nothing continues as you let go.
- The right stick tilts the pile of dots on the Game Over screen, so they roll the way you push it. Let go, and they fall down again.

The cursor appears when you use the controller and hides when you move the mouse or touch the screen. On an iPad, a controller paired in the iPad's Bluetooth settings works the same way, from the first iPad build made after controllers were turned on there.

### Playing with the pile

When a round ends, its dots tumble into a pile. The round is over by then, so nothing you do to them changes your score. On a phone or tablet, tilting the device rolls the dots toward whichever side is lowest, as if they were marbles in a box, and a shake tosses them high, with a bright ring bursting from each dot and the score rattling. A lid keeps them on the screen. Holding the device upright drops them exactly as they always fell, and on a computer without a controller they always fall straight down.

You can also pick up a dot with a finger or the mouse and drag it about. It follows the pointer, pushes the other dots out of its way, and flies off at the pointer's speed when you let go. Each finger holds a dot of its own. A press that stays still and lets go quickly is a tap, which on the Game Over screen does nothing unless it is on a button, so neither a drag nor a stray tap ever ends Game Over by mistake. During a round, every tap still counts the moment it lands. For the first three rounds, a line above **Continue** says how to play with the pile: how to drag the dots, and, on a phone or tablet, how to tilt them too, or, with a controller, how to push the stick. Nobody has tried it on a real iPad yet, so please report how it feels.

### Reduced motion

Setting the environment variable `DOT_POPPER_CALM=1` before starting the game turns off the screen shake that follows a mistake, and makes the dots settle gently at the end of a round instead of bouncing. Tilting the pile then turns it slowly, shaking never throws the dots, and a dragged dot follows more gently and is thrown only softly.

## Installing and running

### Without Ruby

Most players will want a packaged build, which needs no Ruby. Tagged releases are on the [Releases page](https://github.com/Kerrick/dot_popper/releases), with a Windows installer and `.zip`, a macOS `.dmg`, and a Linux `.tar.gz` and AppImage, each built by Lota's `lota fuse`, and, from v0.8.2-rc.1 on, a playtest kit for each device. The [Package workflow](https://github.com/Kerrick/dot_popper/actions/workflows/package.yml) also builds the apps on every push to `trunk`. [PACKAGING.md](PACKAGING.md) explains how the builds and kits are made, how to install them, and how to build one yourself.

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

An iPad and iPhone version is in progress. It uses Lota's experimental iOS engine and host, by the phone route Lota 0.2.2 documents, and the Kits workflow builds it into an Xcode project to sign and install with a free Apple ID (PACKAGING.md, "The iPad and iPhone kit"). Its results sheet is `ios-results.txt`; older kits called it `ipad-results.txt`. The game has run in iPad Simulators but not yet on a real device. [doc/ios.md](doc/ios.md) describes what the game needs from an iOS build and how to tell whether a run went well.

### On an Android phone

An Android version is an experiment. No Lota release builds for Android yet, so the Android workflow builds a debug APK from an unreleased Lota commit (PACKAGING.md, "The Android kit"). It has run on an Android 13 emulator but not yet on a real phone.

## How the dot's size is chosen

Every distance and speed in the rules is measured in multiples of one number: the dot's radius, which the code calls R. Choosing R well matters, because a dot needs to be a comfortable target for a mouse and for a finger alike. The goal is a radius of 50 logical pixels under a mouse, and about 8 mm under a finger. (A logical pixel is a pixel after the operating system's display scaling; on a 2× display, each logical pixel is drawn as four physical ones.)

`conf.rb` turns on Lota's `t.highdpi` setting. With it on, Lota measures graphics in logical pixels on a desktop, and in points (on iOS) or density-independent pixels, called dp (on Android). Lota reports the display's scale as `Lota::Graphics.dpi_scale`, but neither Lota nor LÖVE can report how many pixels fit in a millimetre of the actual screen. So the game can't compute an exact 8 mm. Instead, `DotPopper::DotSize` sets R to 50 units on every system when the game starts. On a desktop that is 50 logical pixels. On a touch screen it is 50 points or dp, which measures 7.9 to 9.6 mm on current iPhones and iPads, and 7.9 mm by Android's definition of a dp. The game prints its choice when it starts, with a line naming the graphics renderer, and one, again on every resize or turn, giving the window's size in units and in pixels, the scale between them, the safe area, and the window's mode.

Because R is fixed, the number of radii that fit on the screen varies from device to device, and a more crowded screen makes for a harder game. The desktop window therefore opens at 24 × 16 R (1200 × 800 logical pixels), which is about the size of an 11-inch iPad measured in radii, so that rounds on a computer and on an iPad play alike. For the same reason, bests are kept separately for small, medium, and large screens. The cut-offs, 250 and 700 square radii, are in `lib/dot_popper/rules.rb`.

Since the iPhone playtest, the game replaces that fixed R with one sized to the screen, unless the player chooses Standard on the title. At the start of each round, `DotPopper::DotSize.fitted` sets R so that the field's area is 24 × 16 = 384 square radii: R = √(width × height ÷ 384). R is never under 30 units, and never over a seventh of the screen's shorter side. `DotPopper::DotSizing` holds the player's choice. [doc/decisions.md](doc/decisions.md) gives the measurements behind these choices, including the simulation of both settings.

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

### The windowed tests

```sh
bundle exec rake test:gui
```

`rake test` checks every layer but never runs the game itself. `rake test:gui` does: it starts the real game with `bundle exec lota run`, once for each of nine short scripted sessions, and each one opens a window, plays, checks what happens as it goes, and quits. The sessions are a whole round from the title back to the title by its buttons (with a few pops, a wrong tap on a popped dot over the fresh one, the lesson it brings, and a click on Game Over's empty space, which must not go on), resizing the window and switching to fullscreen during a round and on Game Over, the Records screen, the Credits screen scrolled by wheel, keys and a finger, clearing the records by a held press and undoing it (and a press let go too soon, which changes nothing), choosing the dot size in a narrow window, dragging and throwing the Game Over pile by mouse, by a pretend gamepad and with a pretend tilt, the words changing between "Click", "Tap" and "Press A", and the whole round again drawn without shaders. Each session checks the rules' numbers, the screens, the save files, and a few pixels of the window. A session that fails prints `FAILED` and the reason, and exits with status 1.

The presses don't move the real mouse pointer. Each session pushes them onto Lota's event queue, and the game's clock moves on by a fixed step each frame instead of real time. So a run plays the same on a fast or a busy computer, and a session takes seconds, not as long as a player would. Every session uses a fixed seed, date and window size, saves in a fresh folder that it removes afterward, so your own records are left alone, and plays no sound (`ALSOFT_DRIVERS=null`).

The suite takes about half a minute, and needs a screen it can open windows on. On your own computer, it opens and closes eight windows, one after another, and switches one of them to fullscreen, so leave the screen alone until it finishes. On a Linux machine without a screen, run it on a virtual one, as the [GUI workflow](.github/workflows/gui.yml) does on every push to `trunk`: `xvfb-run --server-args="-screen 0 1280x1024x24" bash script/with-openbox.sh bundle exec rake test:gui`, with Xvfb, Openbox and Mesa installed. On the maintainer's Mac, it runs in a hidden macOS session:

```sh
S=/Users/kerrick/Developer/hidden_session
$S/stage dot_popper
$S/hidden-run --account deckbuildertest --merge -- /Users/Shared/hidden-session/mirror \
  /Users/Shared/hidden-src/dot_popper/dot_popper /Users/deckbuildertest/dot_popper-mirror
$S/hidden-run --account deckbuildertest --merge --timeout 600 \
  --cwd /Users/deckbuildertest/dot_popper-mirror/dot_popper $($S/toolchain-env dot_popper) \
  --env ALSOFT_DRIVERS=null -- bundle exec rake test:gui
```

To play one session by hand and watch it, set `DOT_POPPER_SCENARIO` to its name (`round`, `resizing`, `records`, `credits`, `clearing`, `dot_size`, `pile`, `pile_gamepad`, or `words`) and run `bundle exec lota run`. `test/gui/scenarios_test.rb` lists the other settings each session needs.

`test/shell/defined_calls_test.rb`, in `rake test`, remains a quick check of the Lota layer without a window: it fails if a method in `lib/dot_popper/shell` calls a method of its own class that doesn't exist.

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
| `DOT_POPPER_AUTOPLAY=1` | A bot plays the game. It mostly taps fresh dots, but now and then it taps a popped dot that covers one, so that penalties appear too. It presses the buttons a player would: **Play** to start each round, **Continue** to go on, and **Copy my result** on every other Game Over. On its second visit to the title, it opens the Records screen for three seconds first and leaves by **Back**. |
| `DOT_POPPER_SHOTS=0.5,3,6.5` | Takes a screenshot at each of these times, counted in seconds of play, and saves them as `shot-1.png`, `shot-2.png`, and so on in the save folder. The game prints each file's path. |
| `DOT_POPPER_QUIT_AFTER=20` | Quits after this many seconds of play. |
| `DOT_POPPER_SEED=42` | Seeds the random number generator, so the same seed and the same taps produce the same dots. |
| `DOT_POPPER_FULLSCREEN=exclusive` | Makes F11 or Alt+Enter take exclusive fullscreen instead of borderless, to compare how each works with system overlays and a TV's game mode. |
| `DOT_POPPER_RENDERERS=opengl` | Chooses the graphics renderer to try (`opengl`, `vulkan`, or `metal`, comma-separated in order), to compare them on one device. Unset, LÖVE picks. |
| `DOT_POPPER_DIAGNOSTIC_COLORS=1` | Clears each frame to pure blue and draws no night, and on iOS paints pure green behind the game's view, to find where a strip at a screen's edge comes from (doc/ios.md, "Diagnostic colours"). |
| `DOT_POPPER_PERF=1` | Every five seconds, prints how many frames a second the game drew and its longest single frame, measured before the game caps how much time one frame may pass to the rules. Useful for checking a new computer. |
| `DOT_POPPER_NO_SPLASH=1` | Leaves out setdef's splash, the maker's name on black for about 1.4 seconds before the title (a tap, click, key, or gamepad button skips it, and it makes no sound). `DOT_POPPER_AUTOPLAY` and `DOT_POPPER_SCENARIO` leave it out too. |
| `DOT_POPPER_NO_SHADERS=1` | Draws plain shapes without shaders. The game does this on its own when a shader fails to compile. |
| `DOT_POPPER_CALM=1` | Turns off screen shake and the bouncing at the end of a round (see "Reduced motion"). |
| `DOT_POPPER_FAKE_TILT=0.6,0` | Pretends to have an accelerometer that always reads this x,y, in g, along the device's portrait axes (x toward its right edge, y toward its top edge). `0.6,0` holds the device tilted to the side, so the Game Over pile rolls to the left. At Game Over the game prints where its tilt comes from: the accelerometer, the fake reading, the gamepad's right stick, or none. |
| `DOT_POPPER_FAKE_GAMEPAD=1` | Plays as if a controller were in hand. The words name its buttons, its cursor shows, Game Over says how to play with the pile using one, and `DOT_POPPER_FAKE_DRAG` makes its drag with the cursor and **A** instead of the mouse. |
| `DOT_POPPER_FAKE_DRAG=0.5,0.9,0.3,0.3` | On each Game Over, 1.2 seconds in, takes the dot nearest the first point, drags it to the second over a second, and throws it there. Each point is a pair of fractions of the window's width and height. The game prints when it takes and throws the dot, to time screenshots by. |
| `DOT_POPPER_WINDOW=400x850` | Opens the desktop window at this size, in logical pixels, to check how a narrow screen looks. |
| `DOT_POPPER_TODAY=2026-11-07` | Plays as if it were that date, to see that day's goal, or to build up a streak of days. |
| `DOT_POPPER_SCENARIO=round` | Plays one of `rake test:gui`'s scripted sessions, checks it, and quits (see "The windowed tests"). |
| `DOT_POPPER_SAVE_AS=test` | Saves in a folder of this name instead of `dot_popper`, so a test run starts with no rounds played and leaves your own records alone. |

### The playtest log

Each finished round adds a line to `rounds.csv` in the game's save folder, so playtests can be compared later. The game prints the file's full path when it starts. Where the save folder is depends on how the game was started:

- Under `bundle exec lota run` on a Mac: `~/Library/Application Support/Lota/dot_popper/`
- In a packaged build: a `dot_popper` folder in the system's application-data folder, such as `%APPDATA%\dot_popper` on Windows (see [PACKAGING.md](PACKAGING.md))

The same folder also holds the game's other saved state: the best scores (`best_score.txt`), whether sound is on, how many times Game Over has explained the stacking rule (`taught.txt`), the choice of dot size (`dot_size.txt`), and the lifetime stats (`lifetime.txt`), which add up every round played on this device. `best_score.txt` and `lifetime.txt` are plain `key=value` lines, with each size of screen's bests under its name, such as `medium=24` or `small.longest_run=9`. A damaged line is ignored, and a missing file starts from nothing. Files saved by earlier versions, which kept one set of bests, give those bests to the size of the screen the game next opens on.

Clearing the records from the Records screen first copies `best_score.txt` and `lifetime.txt`, exactly, to `best_score-<date>-<time>.txt` and `lifetime-<date>-<time>.txt` (for example `lifetime-20261105-093015.txt`) in the same folder, and then empties them. `cleared.txt` says when and names the copies. Only the latest clearing's copies are kept: the next one removes them. To bring cleared records back after Undo has gone, quit the game and copy the two backups over `best_score.txt` and `lifetime.txt`.

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

Dot Popper is copyright 2026 setdef. Like Lota, it is licensed under the [AGPL-3.0-or-later](LICENSE).

The game's sounds are synthesised in code when it starts, and its icon is drawn by `script/make_icon.rb`. The sounds and the icon, like this README and the rest of Dot Popper's documentation, are licensed under [CC-BY-SA-4.0](LICENSES/CC-BY-SA-4.0.txt): reuse them with credit to setdef, under the same license. The Fredoka font is by the Fredoka Project Authors, under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

Lota is an independent project. It is not made, endorsed, or supported by the LÖVE Development Team.
