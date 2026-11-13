<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Development: tests, tools and playtest kits

How Dot Popper is tested and worked on: what each test tier checks and how to run it, the type checker, the GUI scenarios, the guard that keeps automated runs off the internet, the simulator, and the playtest kits. It is for the people and coding agents who change the game. Getting started, the development settings and building an app are in the [developer guide](../README.md); packaging and the kits' contents are in [PACKAGING.md](../../PACKAGING.md). [Why Ruby](../why_ruby.md) is a document of its own.

## The tiers

| Tier | What it runs | Command | Needs | In CI |
| --- | --- | --- | --- | --- |
| Unit tests | `test/**/*_test.rb` except `test/gui/`: the rules, the presentation, friend groups, privacy, continuity, the kits' renderer, and the shell's tests that need no window | `bundle exec rake test` | Ruby and the bundle | The Package workflow's Test job, on every push to `trunk` |
| Steep | The rules in `lib/dot_popper/*.rb` against `sig/` | `bundle exec rake steep` | The `steep` gem (development group) | No workflow runs it |
| Both | `test`, then `steep` (`task default: %i[test steep]`) | `bundle exec rake` | Both of the above | |
| GUI scenarios | The real game in real windows, `test/gui/**/*_test.rb` | `bundle exec rake test:gui` | A display, and Lota | The GUI workflow, on every push to `trunk` and every pull request |
| Packaged apps | Each built app, played by the bot with no Ruby on its `PATH` | See [PACKAGING.md](../../PACKAGING.md#what-ci-checks) | Each platform's runner | The Package and Kits workflows |
| Playtest kits | Hand checks on real devices | See [Playtest kits](#playtest-kits) | A person | The Kits workflow builds and plays them |

Every test task runs with Ruby's warnings on (`t.warning = true`), and `test/no_warnings_test.rb` compiles every file in `lib/`, `script/`, `test/` and the top folder with `-w` and fails on any warning, since a key written twice in one hash only warns.

To run one file: `bundle exec ruby -Ilib -Itest test/rules_fuzz_test.rb`.

[AGENTS.md](../../AGENTS.md) says what to run before each push and where heavy work runs. Tests are fast and reliable, and none reaches the real internet (see [Automated runs stay off the internet](#automated-runs-stay-off-the-internet)).

## Steep, in strict mode

[ADR-0004](../adr/0004-steep-checks-the-rules-strictly.md) records why the rules are type-checked. How:

- The `Steepfile` has one target, `core`, which checks `lib/dot_popper.rb` and `lib/dot_popper/*.rb` against `sig/`, with the `date` and `socket` libraries. The presentation (`lib/dot_popper/presentation/`) and the shell (`lib/dot_popper/shell/`) are not typed; the shell would need Lota's signatures too.
- Diagnostics are `Steep::Diagnostic::Ruby.strict`, so a call Steep cannot type is an error, not a silent `untyped`.
- `sig/dot_popper/` holds one `.rbs` file for each rules file, and `sig/dot_popper.rbs` the module. `untyped` appears only where a parameter takes anything (an environment, a host, a receipt's text) and in `Automation`'s guards over `TCPSocket` and `Socket`. `automation.rb` has two `# steep:ignore UnexpectedSuper` comments, on the `super` calls of its prepended modules.
- RBS's built-in signatures leave out `Data#initialize`, so `sig/core/data.rbs` declares it. That lets a value class's own `initialize` call `super` with keywords, as `Field` does.
- `steep` is in the Gemfile's `development` group, required by nothing, and cached in `vendor/cache`. `rake test` never loads it, so a machine without it can still run the tests.

A new file in `lib/dot_popper/` needs its signature in `sig/dot_popper/`, or `bundle exec rake` fails.

### Why the rules avoid pattern matching

Steep 2.1 does not check `case`/`in`. It reports it as unsupported syntax, a diagnostic that is silent by default, and treats everything inside as untyped, so a type error inside such a branch passes. So the `Steepfile` raises `Steep::Diagnostic::Ruby::UnsupportedSyntax` to `:error`, and the rules branch only in forms Steep can narrow:

- `if`/`elsif` on a predicate or `nil?`, as `Game#tap_at` does with `dots.top_at(x, y)`: `nil` is `Events::Missed`, a `bright?` dot is popped, and anything else is a mistake.
- `is_a?` on a state, after which Steep knows its members: after `state.is_a?(Playing)` in `Cabinet`, `state.game` exists.

Pattern matching is fine wherever Steep does not look: the tests (the fuzz test matches each tap's event), `script/simulate.rb`, `script/playtest_kit.rb` and `playtest/kit.rb`. When Steep checks pattern matching, the branches can be rewritten and the `UnsupportedSyntax` line removed.

## The seeded fuzz test

`test/rules_fuzz_test.rb` plays random games against the real rules and checks, after every step, what must always be true. It needs no extra gem.

`test_random_play_keeps_every_rule` plays `ROUNDS` (2,000) games of up to `STEPS` (40) steps each, every one on a random field from 40 to 3,000 units wide and 40 to 1,800 high, with dots of radius `Rules::RADIUS`: from a sliver narrower than a dot to a large monitor. Each step is one of:

| Step | Share | What it does |
| --- | --- | --- |
| Tap | 60% | 80% aimed within 1.3 radii of a random dot, bright or popped, so taps often land where dots overlap; the rest anywhere |
| Tick | 33% | `game.update` by up to 0.2 s, or one time in ten by up to 20 s |
| Resize | 7% | Half the time a phone's turn (width and height swapped), else a new random field |

After each step it checks that:

- every dot is inside the field;
- the score never goes below `Rules::LOWEST_SCORE`, and changes only by `POP_POINTS` for a pop, by `PENALTY_POINTS` or as many as are left for a mistake, and not at all for a miss, and each event reports those points;
- the clock never goes negative; a tick takes off exactly its seconds, down to zero; a pop adds `POP_SECONDS`, and a mistake takes off `PENALTY_SECONDS` or what is left;
- exactly one dot is bright while the game runs;
- a tap reaches the topmost dot under it and changes no other dot; a miss and a mistake change no dot at all;
- older dots stay above newer ones;
- a tick changes no dot's place in the stack;
- a resize keeps every dot, its order, whether it is popped and its velocity, moves each in proportion across the field's room, and changes neither score nor clock;
- every new dot offers a touch target within the lookahead (`SpawnCheck#exposed_soon?`), or used all `Rules::SPAWN_TRIES` redraws of velocity and of place ([ADR-0002](../adr/0002-a-new-dot-offers-a-touch-target-within-a-second.md)).

`test_random_presses_change_a_game_only_while_it_is_played` drives a whole `Cabinet` for 3,000 steps of random presses and updates of up to 1.5 s, checks that nothing outside `Cabinet::Playing` changes the score or the clock, and that the run reached all three states (`Home`, `Playing`, `GameOver`).

Both tests start from seed 20,261,105. Every failure message names the seed and the game (`seed 20261105, game 512`). To try other seeds, or replay one that failed:

```console
$ RULES_FUZZ_SEED=12345 bundle exec ruby -Ilib -Itest test/rules_fuzz_test.rb
```

## Ractors

The rules' values (fields, dots, stacks, countdowns, events, `DotSize`, `DotSizing`, `SizeClass`) are deeply frozen, so any Ractor can read them without a copy. `test/ractor_test.rb` holds that in place:

- `test_the_rules_values_can_be_shared_between_ractors` asserts `Ractor.shareable?` for one of each value, events included. A value that builds a string at run time, such as a reason or a name, must freeze it.
- `test_the_rule_numbers_can_be_read_from_any_ractor` asserts it for every constant in `Rules`, and `DotSize::TOUCH_SYSTEMS`.
- `test_a_game_played_in_a_ractor_matches_one_played_here` plays one seeded game here and one in a Ractor (`RactorTest.play_a_game`) and asserts they end with the same score and dots.

### On Windows, the game in a Ractor is skipped

On Windows only, the third test skips with `RactorTest::WINDOWS_RACTOR_GC`. On Ruby 4.0.9 (x64-mingw-ucrt), a garbage collection started in a Ractor other than the main one deadlocks while the main Ractor has another thread asleep, and Minitest's worker threads are asleep in every run. The fault is Ruby's, not the rules'; three lines show it with nothing of the game's:

```ruby
Thread.new { sleep }
sleep 0.1
p Ractor.new { 20.times { GC.start }; 1 }.value # never returns on Windows; at once on Linux
```

The same lines with no other thread return at once on Windows, as does the game in a Ractor outside Minitest, or inside it with `GC.disable`. The other two Ractor tests run on Windows, and Linux and macOS run all three. Delete the `skip` once a Ruby release runs the three lines on Windows.

## The defined-calls check

The shell talks to Lota, so most of it runs only in a window, and a call to a method that doesn't exist would surface only when that line first runs in front of a player. `test/shell/defined_calls_test.rb` loads Lota and `dot_popper/shell` without a window, parses every file in `lib/dot_popper/shell/` with Prism, and for each class checks that every receiverless call in its own method bodies (leaving out nested classes, setters and `it`) names a method the class defines, privately or not, responds to, or `Kernel` has. Where Lota isn't installed, it skips.

It catches a missing method, not a wrong argument to Lota or a callback never wired up. The GUI scenarios catch those.

## The GUI scenarios

`bundle exec rake test:gui` plays the real game in real windows. [ADR-0005](../adr/0005-gui-scenarios-play-the-real-game.md) records why.

### How a run works

- `test/gui/scenarios_test.rb` (`GuiScenariosTest`) starts the game once a test, as a developer does: `bundle exec lota run .`, with `DOT_POPPER_SCENARIO` naming a scenario. It passes when the game quits with status 0 after printing `gui: scenario NAME passed` and each line the test names.
- `main.rb`'s last line loads the director (`test/gui/director.rb`) only when `DOT_POPPER_SCENARIO` is set, read through `Build.settings`, which drops it in a store build. A normal launch never loads it.
- `DotPopperGui::Director` prepends `Hooks` to Lota's callbacks. Each frame's `update` goes straight to the `App` (past its `FrameClock`) with the step the scenario asks for, `Scenario::STEP` (a sixtieth of a second) unless it asks for more, not the real time that passed. `vsync` is off, so a run goes as fast as the window draws.
- A scenario runs in a `Fiber` and yields its next step. It prints `gui: ok - …` for each check, and raises `DotPopperGui::Failure` on the first that fails.
- The director stands in for Lota's error screen, which would wait for a player: any error, the game's own included, prints `FAILED scenario …` with a backtrace and exits with 1. A quit the game asks for while the scenario plays is counted (`quits`) and held back, so a scenario can press Quit, check it asked, and play on.

### Input, windows and pixels

- Presses go onto Lota's own queue with `Lota::Event.push` (`Scenario#push`), so they reach `main.rb`'s callbacks on the next frame by the path a player's do: `click`, `press`, `release`, `move`, `touch`, `touch_down`, `touch_move`, `touch_up`, `key`, `wheel`, `pad`.
- Lota can't queue a `Joystick`, and its queue ends a message at the first `nil`, so a pushed gamepad press carries `Scenario::PAD` (0) in the pad's place. `main.rb` never asks which pad pressed. Only a real stick moves the gamepad's cursor, so a gamepad drag uses `DOT_POPPER_FAKE_GAMEPAD` and `DOT_POPPER_FAKE_DRAG`.
- Resizes go through `Lota::Window.update_mode`, fullscreen through F11 or `Lota::Window.set_fullscreen(on, :desktop)`. While the system changes the window (`settled_window`, up to `WINDOW_FRAMES`, 5,000), frames pass no game time, so the game plays the same however long the system takes.
- Pixel checks read the drawn frame back with `Lota::Graphics.capture_screenshot` into a `DotPopperGui::Shot`, read in graphics units.
- Every wait counts frames, never seconds on the clock (`wait_for(what, within:)`), so a slow machine only makes a run take longer.

### What every run fixes

`GuiScenariosTest#environment` gives every run the same settings, so it plays the same dots on any machine and leaves nothing behind:

| Setting | Value |
| --- | --- |
| `DOT_POPPER_SEED` | `7` |
| `DOT_POPPER_TODAY` | `2026-11-07` |
| `DOT_POPPER_WINDOW` | `1200x800`, unless the test names another (`400x850`, `400x320`) |
| `DOT_POPPER_SAVE_AS` | `dot_popper_gui_NAME_PID`, a folder of its own, removed after the run |
| `DOT_POPPER_SERVER` | empty: no friend-group server |
| `ALSOFT_DRIVERS` | `null`: silent |

A test may add settings of its own, such as `DOT_POPPER_PRO`, `DOT_POPPER_TUTORIAL`, `DOT_POPPER_GUI_INPUT` or `DOT_POPPER_FAKE_TILT`.

### Adding a scenario

Subclass `DotPopperGui::Scenario` in `test/gui/scenarios/`, name it with `scenario :name`, and write `#play` top to bottom as the session goes, using the common moves (`start_game`, `pop_fresh`, `run_out_the_clock`, `continue_to_home`, `play_again`, `quick_game`). Then add a test to `scenarios_test.rb` that calls `play("name", *lines, window:, **env)` with the lines it must print. A scenario no test names never runs in the suite.

Two Windows habits for scenarios: compare the clipboard by lines, since Windows ends each line with CR LF there (`share.rb`), and turn back slashes into forward ones before `Dir[]`, since Lota's save folder on Windows has back slashes (`clearing.rb`).

### Where it runs

The GUI workflow (`.github/workflows/gui.yml`) runs it on `ubuntu-latest` under a virtual display, with Mesa's software OpenGL (llvmpipe, `LIBGL_ALWAYS_SOFTWARE=1`) and `ALSOFT_DRIVERS=null`, as Lota's own Linux CI runs its windowed tests:

```console
$ xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" bash script/with-openbox.sh bundle exec rake test:gui
```

`script/with-openbox.sh` starts Openbox, waits until it has taken the screen (`_NET_SUPPORTING_WM_CHECK`), then runs the command, so the game's window has a window manager to go fullscreen with. Elsewhere, run it on a build machine under a virtual display, or in a hidden session, never on a screen someone is using ([AGENTS.md](../../AGENTS.md)).

On Windows, the resizing scenario needs a display at least 1,200 × 800 units (such as 2,560 × 1,600 pixels at 200%, or 1,920 × 1,080 at 100%). It opens at 1,200 × 800 and asks for 800 × 500 and 1,100 × 700 (`ResizingScenario::SIZES`). Windows doesn't give a window a size that won't fit the display at its scale, so on a smaller display the window ends at the game's minimum, 400 × 320 (`conf.rb`), and the scenario waits for 800 × 500 in vain. It passes under Xvfb at 1,280 × 1,024.

### Galleries

Eight scenarios are galleries, which save screenshots to look at by eye and check little: `home_gallery`, `redesign_gallery`, `screens_gallery`, `themes_gallery`, `holiday_gallery`, `offer_gallery`, `games_gallery` and `website_gallery`. No test in `scenarios_test.rb` names them, so `rake test:gui` never runs them. Each file's header says what it shows and which settings it reads (`DOT_POPPER_GALLERY` names the shots; `themes_gallery` and `holiday_gallery` read `DOT_POPPER_THEME` and `DOT_POPPER_THEME_UNLOCKS`, and `holiday_gallery` plays the same game for every theme given the same `DOT_POPPER_SEED`; `games_gallery` needs `DOT_POPPER_FREE_GAMES=0`; `screens_gallery` runs once with `DOT_POPPER_PRO=1` and once with `0`, and its friend-group screens need a local fake such as `script/group_stub.rb`). Run one as the suite runs a scenario, with a hard timeout:

```console
$ timeout 300 env DOT_POPPER_SCENARIO=home_gallery DOT_POPPER_GALLERY=before DOT_POPPER_SAVE_AS=gallery_home \
    DOT_POPPER_SEED=7 DOT_POPPER_TODAY=2026-11-07 ALSOFT_DRIVERS=null bundle exec lota run .
```

It prints `gui: screenshot PATH` for each file it saves in the save folder. `DOT_POPPER_QUIT_AFTER` won't end a scenario, since the director holds back the game's own quits while one plays; use `timeout`. Look at every screenshot at the size it will be seen.

## Automated runs stay off the internet

`DotPopper::Automation` (`lib/dot_popper/automation.rb`) decides whether a run is automated and keeps every automated run off the internet, so nothing in production (a theme released, a store's answer, the network being down) can change its result.

- **Automated** means any of `Automation::FLAGS` is set to something other than empty or `0`: `DOT_POPPER_AUTOMATED`, `DOT_POPPER_AUTOPLAY`, `DOT_POPPER_SCENARIO`, `DOT_POPPER_QUIT_AFTER` or `DOT_POPPER_SHOTS`. That covers the test suite (`test/test_helper.rb` sets `DOT_POPPER_AUTOMATED=1`), the GUI scenarios and galleries, the bot, CI's packaged-app playthroughs and the Android emulator checks (which pass `DOT_POPPER_AUTOMATED=1`). In a store build, `Build.settings` drops `DOT_POPPER_AUTOMATED` and `DOT_POPPER_SCENARIO`, so there only the bot, `QUIT_AFTER` and `SHOTS` make a run automated.
- **The guard.** `Automation.guard!` prepends modules to `TCPSocket.new`, `TCPSocket.open` (which `Net::HTTP` uses) and `Socket.tcp` that refuse any host but `localhost`, `127.0.0.1` and `::1`. In the tests, a refusal raises `Automation::OutsideConnection` (an `Exception`, not a `StandardError`). In the game (`Shell::App#initialize`, `exit_on_attempt: true`), it prints why and exits with status 70, so the check that started it fails.
- **What else follows.** An automated run has no friend-group server unless `DOT_POPPER_SERVER` names one (`Network::Settings.server_url`), starts no store helper (`Shell::StoreHelper`), and never asks setdef's real server whether it is gone (`Shell::App#watch`).
- **Local fakes are allowed**, such as `script/group_stub.rb` and `test/privacy`'s local server.

`test/automation_test.rb` checks which settings make a run automated, that the suite cannot reach an outside host by either socket call or through `Network::Link`, and that a local server is reachable. `test/build_test.rb` checks that `DOT_POPPER_AUTOMATED` and `DOT_POPPER_SCENARIO` don't make a store build automated.

## The simulator

`script/simulate.rb` plays the real rules with a model player, without a window, to see how the field's size in radii changes a game. It is a design tool, not a test.

```console
$ bundle exec ruby script/simulate.rb [games]
$ bundle exec ruby script/simulate.rb bonus [games [rows [points [seconds]]]]
```

`games` defaults to 200 per run.

### The model player

`Simulation::Player` updates the game 30 times a second (`STEP`). It waits a reaction time (`REACTION`, 0.25 s) after each new bright dot, then moves to it in the time Fitts's law gives (`FITTS_A` 0.10 s, plus `FITTS_B` 0.15 s a bit with a mouse or 0.12 s by touch), and taps its middle. While the bright dot is covered it waits in 0.1 s steps, and with a chance of `IMPATIENCE` (4%) each step taps anyway and makes a mistake on the popped dot on top. A game longer than `GIVE_UP` (240 s) counts as endless.

### What it plays

`DEVICES` holds six screens, in radii: an upright iPhone (7.9 × 17), an 11-inch iPad (16.4 × 23.6), a 13-inch iPad Pro (20.6 × 27.5), the reference window (24 × 16), a 27-inch 1440p monitor (51.2 × 28.8) and a 32-inch 6K monitor (60.2 × 33.8). `JOBS` plays each device with each `DotSizing` (standard, and sized to the screen), with the spawn rule (`Rules::SPAWN_TRIES`) and without it (0): 24 jobs. It prints a table for each dot size: each device's radius and area in square radii, mean and 90th-percentile score, game length, share of endless games, mistakes, the share of spawns redrawn and moved, and, without the rule, the share of spawns with no touch target for a second and the mean score.

### Ractors, and the larger heap

Each job plays in a Ractor of its own, and then all again one after another. Each starts its own `Random.new(2026)`, so both ways play the same games; the script aborts if they differ, and prints how much sooner the Ractors finished.

Ruby 4.0 stops every Ractor for each garbage collection, and a game makes much short-lived garbage (new dots and a new stack every step). With Ruby's default starting heap, the Ractors spend their time waiting for one another. So the script's first lines `exec` it again with `RUBY_GC_HEAP_0_INIT_SLOTS`, `_1_` and `_2_` at a million slots each (`GC_HEAP`, about 250 MB), unless they are already set.

Measured, not enforced: with the default heap, 10 games per device caused about 1,100 collections, and the Ractors ran 0.7 to 1.2 times as fast as one after another; with the larger heap, about 25 collections, and 60 games per device took 28.9 s one after another and 14.5 s in Ractors on the maintainer's Mac, whose ten cores were mostly busy with other work. A run of 20 games took 36 seconds on an M1 Max ([developer guide](../README.md#tests)).

### The `bonus` mode

`bonus` compares candidate numbers for the bonus dot (`Rules::Bonus`) on three devices (`BONUS_DEVICES`: the upright iPhone, the reference window and the 27-inch monitor), with dots sized to the screen and the spawn rule on. `rows`, `points` and `seconds` are comma-separated lists; by default dots in a row of 6, 8, 10 and 12, 2 or 4 points, and 2, 4 or 6 seconds, every combination, and no bonus dot at all. For each it prints the mean and 90th-percentile score and length, the share of endless games, mistakes, bonus dots earned per game, and how often a game meets each of the daily goals (`DailyGoal::LIST`). It runs in Ractors only. The rules the numbers set are in [rules.md](rules.md).

## The spawn benchmark

`script/benchmark_spawn.rb` times the spawn rule (`Spawner#spawn`) with 100 popped dots on the field (`SpawnBenchmark::DOTS`), about as many as a long game on a big monitor ends with, on five fields: the 27-inch monitor, the 6K monitor sized to the screen, the reference window, and an upright iPhone at the standard size and sized to the screen. It counts this thread's CPU time, so a busy machine skews it less, and prints the mean, 99th-percentile and longest time in milliseconds, and the share of spawns redrawn and that used every try.

```console
$ bundle exec ruby script/benchmark_spawn.rb [spawns]   # 500 by default
```

Measured, not enforced, on the maintainer's Mac: on the 27-inch field a spawn took 0.08 ms on average and 0.6 ms at the 99th percentile; on an upright phone's field packed with 100 dots, 1.7 ms and 6 ms, with 70% of spawns redrawn and 10% using every try. A spawn happens once per pop, so it only has to be quick next to a frame.

## Playtest kits

[PACKAGING.md](../../PACKAGING.md#playtest-kits) says what each kit holds, what its script records, and how CI builds and plays it. What it leaves out:

- **One kit in, one results file out**, per device, is the maintainer's rule: he opens one kit, plays, and sends back one file, with nothing to coordinate between kits. On Windows and Linux, `playtest.ps1` and `playtest.sh` write everything into `dot-popper-results.txt`; the macOS, iPhone and iPad, and Android kits carry a sheet to fill in, since a script can't start the phone apps.
- **The words live in one place.** Every check is in `playtest/checks.yml`, whose header documents each field (`id`, `ask`, `answer`, `try`, `restart`, `after`, `group`, `parts`, `quotes`). `playtest/kit.rb` (`Playtest::Checklist`, `PowerShellList`, `ShellList`, `ResultsSheet`) renders them, loads neither the game nor Lota, and `script/playtest_kit.rb` runs it. Copied into four scripts and sheets, questions would drift apart, and a question that names a button by a word the game no longer uses confuses the player it is meant to help.
- **`test/playtest_kit_test.rb`** checks the lists' lengths (18 desktop checks with 14 to 18 for a controller, 13 for iOS, 15 for Android), that every check has wording and a known kind of answer on every system, that each phrase in `quotes` is in the check's words and in a string of `Presentation::Style`, that Windows' words are ASCII, and both renderings and the version rules below.
- **The mute check restarts the game.** Check 2 has `restart: true`: the Windows and Linux scripts wait for the player to quit, then start the game again before asking whether the mute held, so the restart is one step for the player. If the game has closed by itself before any check, the script notes it and starts it again. Each start is its own session in the results, with its own output.
- **A tagged kit takes the tag's version.** `script/playtest_kit.rb tag-version REF fledge.yml` sets the version in CI's copy of `fledge.yml` to the tag's, without its `v` (`Playtest::BuildVersion`); a release candidate (`v0.8.2-rc.1`) takes its base (`0.8.2`), since `CFBundleShortVersionString` and Windows' file version take only numbers. A build by hand or of a branch keeps `fledge.yml`'s. `check-build REF BUILD` fails unless the kit's header begins `Dot Popper REF,` and ends `, version VERSION`; the Kits workflow runs both for every kit.
- **To read what a kit will ask**, render it: `ruby script/playtest_kit.rb sheet ios /tmp/ios-results.txt`, or `windows`, `linux`, `sheet mac`, `sheet android`. A new results sheet needs its device in `ResultsSheet::DEVICES`.

What each playtest on a real device found is in [doc/playtests](../playtests/).
