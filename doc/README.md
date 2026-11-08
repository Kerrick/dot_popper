<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Dot Popper: developer guide

[![Package](https://github.com/setdef/dot_popper/actions/workflows/package.yml/badge.svg?branch=trunk)](https://github.com/setdef/dot_popper/actions/workflows/package.yml) [![GUI](https://github.com/setdef/dot_popper/actions/workflows/gui.yml/badge.svg?branch=trunk)](https://github.com/setdef/dot_popper/actions/workflows/gui.yml) [![Ruby](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FKerrick%2Fdot_popper%2Ftrunk%2F.ruby-version&search=(.*)&replace=%241&label=Ruby&logo=ruby&color=ffbf52)](#requirements)

Dot Popper is a 2D arcade game written in Ruby. It runs on [Lota](https://github.com/setdef/Lota), which runs the engine that [LÖVE](https://love2d.org) games run on, with Ruby in place of Lua. [Fledge](https://github.com/setdef/Fledge) packages it into apps for Mac, Windows, and Linux that players run without Ruby. For what the game is and how to install it, see the [README](../README.md).

This guide is for Rubyists who want to build Dot Popper from source, change it, or read a finished Lota game from its first frame to its installer.

## What's in the code

- **Rules you can test without a window.** The rules, in `lib/dot_popper`, are 1,557 lines, built mostly from immutable values made with `Data.define`. They draw nothing, play nothing, and read no input. 517 unit tests run in about 3 seconds, and [Steep](https://github.com/soutaro/steep) checks the rules against RBS signatures in strict mode.
- **The look and sound as plain values.** `lib/dot_popper/presentation` (4,869 lines) holds every color, word, size, timing, and animation curve, and the synthesizer that makes every sound when the game starts. It never calls Lota, so its tests run without a window too.
- **LÖVE's engine, from Ruby.** `lib/dot_popper/shell` (3,038 lines) does the drawing, sound, and input through Lota: four GLSL shaders, LÖVE's particle systems for the pop droplets, Box2D physics for the pile at Game Over, stereo sound, mouse, touch, gamepads, and a tablet's accelerometer.
- **A game that plays itself.** A bot plays rounds by itself. Ten scripted scenarios play the game in a real window, check it as they go, and quit. A simulator plays the real rules with a model player on screens from an iPhone to a 32-inch monitor.
- **Shipped like any other game.** On every push to `trunk`, CI builds the app for each desktop on that desktop, then plays each one for 20 seconds with no Ruby on the PATH.

If you know LÖVE, [Why Ruby](why_ruby.md) sets Dot Popper's code beside the Lua a LÖVE game would use for the same job, and says where Lua wins.

## How the code is laid out

| Path | What it holds |
| --- | --- |
| `main.rb` | Hands each of Lota's callbacks to `DotPopper::Shell::App`. Its comments list every control and development setting |
| `conf.rb` | Lota's window settings: the title, the 1200 × 800 window, the save folder's name, and which graphics renderers to allow |
| `lib/dot_popper/` | The rules. `rules.rb` holds every number that sets how the game plays, in dot radii; `round.rb` and `stack.rb` hold a round and its dots |
| `lib/dot_popper/presentation/` | How the game looks and sounds, as values. `look.rb` holds every setting, and `words.rb` writes every sentence the player reads |
| `lib/dot_popper/shell/` | Carries out the presentation with Lota: painters, the speaker, input, and save files |
| `bin/dot_popper` | The program in the packaged app. It starts the game as a fused Lota game, which saves in a folder named after the game, as a fused LÖVE game does |
| `fledge.yml` | The app's name, version, identifier, icon, and installers, for Fledge |
| `sig/` | RBS signatures for the rules |
| `test/`, `test/gui/` | Unit tests, and the scenarios that play the game in a window |
| `script/` | The simulator, a spawn benchmark, the icon's drawing script, and the playtest kits' renderer |
| `playtest/` | The questions and scripts in each playtest kit |
| `ios/`, `android/` | Dot Popper's changes to Lota's iOS and Android hosts, for the experimental phone builds |
| `vendor/cache/` | Every gem the game uses, including Lota's precompiled gems, which are not on RubyGems.org |

## The friend-group server

The server is a separate Rails app, `~/Developer/dot_popper-server`; what it must do is in `doc/server.md`. The game speaks to it with `lib/dot_popper/groups/` (no `/v1` prefix; JSON; a bearer token). It holds no names or text: a member is one of eight looks (`lib/dot_popper/groups/mark.rb`), and a group's code is seven digits.

The game looks for the server at `Groups::Settings::SERVER_URL`, which is `nil` until one is deployed: with no address, no Group button appears and the game connects to nothing. Run the game with `DOT_POPPER_SERVER=http://localhost:3000` to try a local server.

## Requirements

| You develop on | Lota's gem in `vendor/cache` |
| --- | --- |
| macOS 14 or newer on Apple silicon | `lota-0.2.2-arm64-darwin.gem` |
| Windows on x64, with [RubyInstaller](https://rubyinstaller.org/)'s Ruby | `lota-0.2.2-x64-mingw-ucrt.gem` |
| Linux on x86_64 with glibc, and an X11 or Wayland desktop with OpenGL | `lota-0.2.2-x86_64-linux-gnu.gem` |

- Dot Popper needs Ruby 4.0.9, which `.ruby-version` and `mise.toml` name.
- Bundler installs Lota 0.2.2 from `vendor/cache`, and [Fledge](https://github.com/setdef/Fledge) v0.8.0 from its Git tag. Fledge is in the `development` group, so it stays out of the app.
- Other systems, such as Intel Macs, Linux on ARM, and Linux with musl, have no Lota gem in `vendor/cache`.

## Getting started

Clone the repository, install Ruby and the gems, and run the game:

```console
$ git clone https://github.com/setdef/dot_popper.git
$ cd dot_popper
$ mise install
$ bundle install
$ bundle exec lota run
```

`mise install` installs Ruby 4.0.9. Any Ruby version manager that reads `.ruby-version` works as well. `bundle exec lota run` opens the game in a window and prints what it found, such as:

```text
Dot Popper: a dot's radius is 50 logical pixels
Dot Popper: renderer Metal 2.1 /  / Apple M1 Max
Dot Popper: screen 1200x800 units, 2400x1600 pixels, dpi scale 2.0 (native 2.0), safe area 0,0,1200,800, mode 1200x800 windowed, usedpiscale true
Dot Popper: each round is logged in ~/Library/Application Support/Lota/dot_popper/rounds.csv
```

Run unfused like this, the game saves in a `Lota` folder, apart from the packaged app's save folder, so your test rounds never touch your real records.

### Development settings

The game reads these from its environment. `main.rb` lists them all.

| Setting | What it does |
| --- | --- |
| `DOT_POPPER_AUTOPLAY=1` | A bot plays: the title, a round, Game Over, and again. It sometimes taps a popped dot, so penalties show |
| `DOT_POPPER_NO_SPLASH=1` | Skips setdef's splash screen |
| `DOT_POPPER_SAVE_AS=test` | Saves in a folder of this name, so a run starts with no records |
| `DOT_POPPER_SEED=42` | Makes the dots' randomness repeatable |
| `DOT_POPPER_TODAY=2026-11-07` | Plays as if it were that date, for the daily goal and its streak, and for which holiday look is in season (try `2026-10-31`, `2026-12-25` or `2027-02-14` with `DOT_POPPER_PAID=1`) |
| `DOT_POPPER_WINDOW=400x850` | Opens the window at this size, to check a narrow screen |
| `DOT_POPPER_SHOTS=0.5,3,6.5` | Saves a screenshot at each of these seconds after start, in the save folder |
| `DOT_POPPER_QUIT_AFTER=20` | Quits after this many seconds |
| `DOT_POPPER_PERF=1` | Prints frames per second and the longest frame, every five seconds |
| `DOT_POPPER_NO_SHADERS=1` | Draws with plain shapes, as on a GPU whose driver cannot compile the shaders |
| `DOT_POPPER_FAKE_GAMEPAD=1` | Plays as if a gamepad were in hand: the words name its buttons, and its cursor shows |
| `DOT_POPPER_FAKE_TILT=0.6,0` | Stands in for a tablet's accelerometer, to roll the pile at Game Over |
| `DOT_POPPER_CALM=1` | Turns off the screen shake, and makes the pile settle gently. Players use this one too |

The screenshots in the README came from bot runs like this one, which saves a screenshot every half second from 12 to 34 seconds in:

```console
$ DOT_POPPER_AUTOPLAY=1 DOT_POPPER_NO_SPLASH=1 DOT_POPPER_SAVE_AS=readme_cover DOT_POPPER_SEED=7 \
  DOT_POPPER_SHOTS=$(ruby -e "puts (12..34).step(0.5).to_a.join(%q(,))") DOT_POPPER_QUIT_AFTER=35 bundle exec lota run
```

The seed repeats the same rounds, but the game times each screenshot by the clock, not by the frame, so two runs catch slightly different moments. Take many, and choose the one that shows the bright dot under a popped one.

## Tests

`bundle exec rake` runs the unit tests and Steep:

```console
$ bundle exec rake
517 runs, 678992 assertions, 0 failures, 0 errors, 0 skips
No type error detected. 🫖
```

- `bundle exec rake test` runs the unit tests alone, and `bundle exec rake steep` runs Steep alone.
- `bundle exec rake test:gui` plays the ten scenarios in `test/gui/scenarios` in real windows. It needs a display, so `rake` leaves it out. CI runs it on every push and pull request, on Linux, under a virtual display with software OpenGL.
- `bundle exec ruby script/simulate.rb 20` plays 20 rounds on each of six screens with a model player, with each dot size, and prints a table of scores, round lengths, and penalties. A run of 20 rounds finished in 36 seconds on an M1 Max. [Decisions made overnight](decisions.md) has the rules its numbers set.

## Building the app

`lota fuse` builds the app for the computer it runs on. It runs Lota's gem from outside the bundle, so install that gem into your Ruby first, from `vendor/cache`:

```console
$ gem install --local vendor/cache/lota-0.2.2-arm64-darwin.gem
$ lota fuse . --identifier com.setdef.DotPopper --app-version 0.9.2 --icon icons/icon
dist/Dot Popper-arm64-darwin.tar.gz
dist/Dot Popper-arm64-darwin.dmg
Built the app for arm64-darwin only. Run lota fuse on each platform you ship for.
```

On an M1 Max, a build finished in about 45 seconds. `lota fuse` needs Git and the network, because Bundler fetches Fledge from GitHub and Fledge downloads its Ruby runtime the first time. On Windows, it also needs RubyInstaller's MSYS2 tools (`ridk install`), because one development gem compiles there. On a Mac, `lota fuse` writes a `.dmg` and a `.tar.gz`; on Windows, a `.zip` and a setup program; on Linux, a `.tar.gz` and an AppImage. To ship all three, build on all three, as CI does. [Packaging Dot Popper](../PACKAGING.md) has what goes in the app, and how CI builds and checks each one.

### Phones and tablets

The iPhone, iPad, and Android builds are experimental, and are not released to players. The Kits workflow builds an Xcode project for iPhone and iPad, and the Android workflow builds an APK and an App Bundle. CI plays each in the iOS Simulator or an Android emulator. A playtester has played a build on a real iPad. See [Dot Popper on an iPad](ios.md) and [Publishing Dot Popper](publishing.md).

### Releases

`version` in `fledge.yml` sets the app's version. A `v*` tag makes CI build every app and playtest kit and attach them to the tag's [GitHub release](https://github.com/setdef/dot_popper/releases).

## Documentation

| Resource | What it holds |
| --- | --- |
| [Packaging Dot Popper](../PACKAGING.md) | Getting a build, how `lota fuse` and Fledge put the app together, building on your own computer, what CI checks, and the playtest kits |
| [Decisions made overnight](decisions.md) | Each call made about the rules, crowding, presentation, and LÖVE's engine, with why, and what it would take to reverse it |
| [Why Ruby](why_ruby.md) | Dot Popper's Ruby beside the Lua a LÖVE game would use, from values and blocks to Ractors, and where Lua wins |
| [Dot Popper on an iPad](ios.md) | What the iOS app needs, how the game behaves there, and how to check a run in the Simulator |
| [Publishing Dot Popper](publishing.md) | What each store needs, from Google Play to Homebrew, and the license question to settle first |
| [Playtests](playtests/) | What each playtest on a real device found, and what it led to |
| [Inspiration](../INSIPIRATION.md) | Optional reading for the game's look and feel: summaries of books on interaction design, visual design, game design, and writing |
| [Lota's README](https://github.com/setdef/Lota) | Lota's API, and how a LÖVE call becomes a Ruby one |
| [LÖVE's wiki](https://love2d.org/wiki/Main_Page) | What each engine function does. Look up a Lota method under its LÖVE name |

## Reporting problems

Open an [issue on GitHub](https://github.com/setdef/dot_popper/issues). For a problem with a build, say which platform you built on, which you ran on, and what `bundle exec lota run` printed.

## Copyright and license

Dot Popper is copyright 2026, setdef, all rights reserved: its code, documentation, sounds, and icon alike. See [LICENSE](../LICENSE). The fonts in `assets/fonts` are under the SIL Open Font License, and each keeps its license beside it. Noto Emoji's pointing hand is under the [Apache License 2.0](../LICENSES/Apache-2.0.txt).

Versions up to and including v0.9.9 were published under the AGPL-3.0-or-later, with their documentation, sounds, and icon under CC-BY-SA-4.0, and remain available on those terms at their tags. Every packaged app carries the notices for Lota, LÖVE, Ruby, and the libraries they bring.

## How Dot Popper is made

I use three words for how code and prose comes to exist. Code or prose I wrote, I typed by hand, with nothing generated. Code or prose I wrought, an AI agent generated while I iterated with it, and I reviewed every change before committing it, so I take responsibility for every diff. Code or prose I requested, an agent built with little or no review from me, in the style of a "dark factory."

Dot Popper's spec, the rules of the game, is wrought. I treat the game as a whole as wrought too, with one difference: I review it by playing it, not diff by diff. I chose what the game does, how it plays, looks, and sounds, and what stays out of it. I iterated with agents on each of those, played builds on my devices, and sent the agents back when the game did not play the way I wanted.

The details are requested. Agents wrote the individual lines of the code, tests, workflows, playtest kits, docs, and this guide, and I did not review those lines. In place of line-by-line review, CI runs gates on every change: the unit tests, Steep, the scenarios that play the game in a window, and the jobs that play each built app with no Ruby on the PATH. Playtests on real devices check what CI cannot see. Each commit names the model that wrote it in a `Co-Authored-By` trailer. Under [declare-ai.org](https://declare-ai.org/1.0.0/creative.html), this is creative assistance.
