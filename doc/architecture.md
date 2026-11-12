<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Dot Popper's architecture

How Dot Popper's code is divided, what each part may depend on, and how a press, a frame and a save move through it. It is for anyone, person or coding agent, about to change the code. The words are `GLOSSARY.md`'s. Why each large choice was made is in the [decision log](adr/README.md); how each area works in detail is in the [design documents](#design-documents).

## The parts

Dot Popper is Ruby on [Lota](https://github.com/setdef/Lota), which runs LÖVE's engine with Ruby in place of Lua. The code is in three layers, an edge, and code outside the game.

| Part | Where | Holds | May use |
| --- | --- | --- | --- |
| **Core** | `lib/dot_popper/*.rb`, and `groups/`, `continuity/`, `receipt/` | The rules (dots, the field, the score, the clock, spawning), the flow from Home to a game to Game Over (`Cabinet`), Stats and records, free games, Pro (`Entitlement`, `Receipt`, `Continuity`), the friend-group client (`Groups`), the build's kind (`Build`), and the guard on automated runs (`Automation`) | Ruby's standard library only |
| **Presentation** | `lib/dot_popper/presentation/` | Everything a player sees, hears and presses that isn't a rule: every number, colour, word, size, timing and animation (`Style`, `Words`), layout plans, effects, the tutorial, the sound synthesizer, input routing, and the `Show`, which ties them to the core's events | The core |
| **Shell** | `lib/dot_popper/shell/` | Carrying the presentation out with Lota: painters, the `Renderer`, the `Speaker`, gamepads, the Game Over pile's physics, save files, the clipboard, URLs, the store helper, and `App`, which wires everything together | The presentation, the core and Lota |
| **Entry points** | `main.rb`, `conf.rb`, `bin/dot_popper` | `conf.rb` sets Lota's window and renderers before the window opens; `main.rb` hands each Lota callback to `Shell::App`; `bin/dot_popper` starts the game fused, for the phone builds | Everything |
| **Native code** | `ios/host`, `android/host`, `macos/store`, `windows/store` | Dot Popper's additions to Lota's phone hosts (the share sheet, the store, platform fixes), and the computer stores' helper programs | Their platform's APIs |
| **Outside the game** | `lib/dot_popper/privacy/`, `test/`, `sig/`, `script/`, `playtest/`, `.github/` | The privacy declarations and their generated document, tests, RBS signatures, the simulator and tools, playtest kits, CI | Anything |

### The rules between them

- **Only the shell calls Lota.** The core and the presentation name Lota only in comments, so all of their tests run without a window (`AGENTS.md` makes this a rule). Code that needs the engine to decide something, such as measuring text, takes it as an argument: the presentation measures with whatever it is given (`Shell::FontMeasure` in the game, `RoughMeasure` in tests).
- **Dependencies point inward.** The core names nothing in the presentation or the shell; the presentation names nothing in the shell. `lib/dot_popper/privacy/` is the exception, by design: it is not loaded by the game, and reads the presentation's words to write the privacy document.
- **The core is values.** Its state is immutable `Data` values, frozen deeply enough to be shared between Ractors (`test/ractor_test.rb`), and changes return new values. `Cabinet` holds the current state and is the one mutable object players' presses reach.
- **The core is typed.** Steep checks `lib/dot_popper.rb` and `lib/dot_popper/*.rb` against `sig/` in strict mode ([ADR-0004](adr/0004-steep-checks-the-rules-strictly.md)). The presentation, the shell and the core's subfolders are not typed.
- **Every outside party is behind a port.** The network is reached only through `Groups::Link`; a store only through the `Storefront` port ([ADR-0009](adr/0009-the-store-is-a-port.md)); a file only through `Shell::SaveFile`; the system's share sheet and stores only by a URL the host catches or a helper process ([ADR-0008](adr/0008-native-features-live-outside-the-ruby-process.md)). Tests source-scan for the first and third ([ADR-0014](adr/0014-privacy-facts-come-from-the-code.md)).
- **The build decides what it trusts.** `Build::CHANNEL` is nil in a test build (every playtest kit and CI run) and names a store in a store build. It alone chooses the store's adapter, the keys and receipts trusted, and which `DOT_POPPER_*` settings are obeyed ([ADR-0010](adr/0010-pro-comes-only-from-proof.md)). `Shell::App` reads the environment only through `Build.settings`.
- **Automated runs reach no outside host.** A test, a GUI scenario, the bot, or any run told to quit or take screenshots by itself sets `Automation.on?`, and `Automation.guard!` then refuses every connection to a host that isn't this machine.

## The game as a state machine

`Cabinet` (`lib/dot_popper/cabinet.rb`) is the game as a whole. Its state is one of three values, `Home`, `Playing` and `GameOver`, each answering `press(x, y)` and `update(seconds)` with the state that follows. `Playing` holds a `Game` (`lib/dot_popper/game.rb`): the field, the `Stack` of dots, the `Countdown`, the score, and the `Spawner`. Only a press at a place reaches a `Game`, so no key or gamepad button can touch the score or the clock, and nothing outside `Playing` changes either.

Each change is announced as an event (`lib/dot_popper/events.rb`): `Popped`, `Penalized`, `Missed`, `GameStarted`, `GameEnded`, `HomeShown`. An event is a frozen value made after the change, and `Cabinet` tells every listener in order. The listeners are the `Show`, `PlaytestLog` (`games.csv`), and in the shell the `Pile`, `Tilting` and `Dragging`.

Screens other than Home, a game and Game Over (Settings, Stats, Achievements, Themes, Friend groups, the Pro offer, Credits, Privacy, the share preview, the tutorial) are the presentation's alone: the `Show` opens them over Home or Game Over, and a press there never reaches `Cabinet`. The tutorial is the exception that leads somewhere: it ends by starting the first game from the state it reached (`Cabinet#resume`; [ADR-0003](adr/0003-how-to-play-is-taught-without-words.md)). Every way into a game, Play, Skip or the tutorial's end, goes through `Show#with_a_game`, which spends a free game ([ADR-0012](adr/0012-free-games-20-then-3-a-day.md)).

## A frame

Lota calls `main.rb`'s callbacks; each goes straight to `Shell::App` (`lib/dot_popper/shell/app.rb`).

1. **Presses.** A mouse, touch or key callback goes through `Presentation::Chatter` (a worn mouse's double click), then `InputRouter`, which turns it into a `Tap` or a pointer move, then `Show#tap`, which decides whether it is for a button, the pile, the tutorial or the game, and passes a game's press to `Cabinet#press` on the frame it happened. A gamepad's A presses at its cursor through the same path.
2. **Time.** `Lota.update` calls `App#tick`, which measures the time between the last two frames starting to draw (`FrameClock`), not Lota's own `dt`, and clamps it to `Rules::LONGEST_FRAME` (0.1 seconds).
3. **Update.** `App#update` moves the gamepad cursor, the bot if it plays, `Cabinet`, the `Show` (its effects, animations, HUD, the screens' state, the store's answers and the friend-group session), the theme feed and the setdef watch, then the shell's tilt, drag, pile physics and particles.
4. **Draw.** `Lota.draw` calls `Renderer#draw`, which draws the `Show`'s state through the `Pen` and the painters straight to the window at its own pixels: the night, the dots and their glow (or the pile after time's up), effects, the screen's words, buttons and HUD, the share preview, and the gamepad cursor.

The GUI scenarios replace step 2 with a fixed step and push presses onto Lota's event queue, so everything else runs as a player's game does ([ADR-0005](adr/0005-gui-scenarios-play-the-real-game.md)).

## Composition

`Shell::App#load` is the composition root. It reads the system (`Lota::System.os`), makes every `SaveFile`, the `Cabinet` with its `ScoreRecord`, `StatsBook`, `Achievements` and `StatsKeeper`, the `Entitlement` with the trusted pins and receipts, the `Storefront` for this build (`Storefront.for`), `FreeGames`, the friend-group `Session`, the `ThemeKeeper` and `ThemeFeed`, the `Pen`, the `Speaker`, and the `Show`, which takes all of them as arguments with harmless defaults. Tests build a `Show` from those defaults, with memory stores in place of files.

`conf.rb` runs before all of this, and before the window opens: it names the save folder (`t.identity`), sets the window, and chooses the renderers, with the rescue that starts the game again without Vulkan when Vulkan can't start it ([ADR-0007](adr/0007-renderers-per-platform-with-a-relaunch-without-vulkan.md)).

## Saving

Everything the game keeps is a text file in Lota's save folder, read and written whole through `Shell::SaveFile`, which refuses any name not declared in `Privacy::SAVE_FILES`. Lota's save folder can't rename or append, so a file is rewritten whole, and a backup is a copy written before the original changes. The core's keepers (`ScoreRecord`, `StatsBook`, `FreeGames`, `License` and the rest) each take a store that answers `read` and `write(text)`, so they work on a memory store in tests. Saves read leniently: a line that can't be read keeps its starting value. `doc/privacy.json` lists every file, what it holds, and what leaves the device.

## Threads

The game runs on Lota's one thread. Network requests run on `Groups::Worker`'s thread, at low priority, started by the first request, so a player with no friend group has no thread; the theme feed and the setdef watch use workers too. A frame reads finished replies and never waits. The simulator and one test use Ractors; the game does not.

## Platforms

One code base runs on macOS, Windows and Linux (built by `lota fuse`, [ADR-0006](adr/0006-lota-fuse-builds-the-desktop-apps.md)) and on iOS, iPadOS and Android (built by Lota's phone guide with Fledge). The differences are in a few places: `DotSize.for` and `DotSize.touch?` by system; `conf.rb`'s renderers; `Shell::Haptics`, `SheetSharing.for` and `Storefront.for` by system; the phone hosts' native files; and the desktop's window controls (`Shell::DesktopWindow`). [Platforms](design/platforms.md) has the details.

## Design documents

| Document | Covers |
| --- | --- |
| [Rules](design/rules.md) | The field, R and dot sizing, spawning and touch targets, scoring and the clock, the bonus dot, time per frame |
| [Progress](design/progress.md) | Stats, records and size classes, the daily goal and streak, achievements, clearing Stats, the games log |
| [Screens](design/screens.md) | Home, Settings, Stats, Game Over, sharing, Credits, the splash, layout plans, buttons and hover |
| [Tutorial](design/tutorial.md) | The tutorial and the wordless signs that teach how to play |
| [Look and sound](design/look-and-sound.md) | How dots, effects and the Game Over pile are drawn, sound, haptics, themes |
| [Input](design/input.md) | Mouse, touch, keyboard and gamepad, the cursor, dragging the pile |
| [Platforms](design/platforms.md) | What differs on each system: renderers, the phone hosts, Android and iOS specifics |
| [Store and Pro](design/store-and-pro.md) | Pro and Free, channels, the store port and adapters, receipts, license keys, free games, the offer |
| [Friend groups](design/friend-groups.md) | The game's side of friend groups; [doc/server.md](server.md) is the server's |
| [Privacy](design/privacy.md) | How the privacy facts are declared, enforced and published |
| [Development](design/development.md) | The test tiers, Steep, the fuzz test, the GUI scenarios, the simulator, playtest kits |

[PACKAGING.md](../PACKAGING.md) covers building and shipping the apps, [doc/ios.md](ios.md) the iOS app, and [doc/publishing.md](publishing.md) the stores.
