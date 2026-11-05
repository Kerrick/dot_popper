# Dot Popper on an iPad

What the game needs from an iOS or iPadOS build, what it does differently
there, and how to tell a good run from a bad one. The app itself is built
outside this repository, with Lota trunk's experimental iOS engine and
`fledge build ios`; this page is the game's side of that build. Nothing
here has run in a Simulator or on a device yet (see "Unverified").

## The program

The app's program is `bin/dot_popper`, as on the desktop (`fledge.yml`,
`programs`). It boots the repository's root as a fused Lota game. `main.rb`
is *not* a program: it only defines Lota's callbacks, so an app that ran it
directly would define them and exit at once.

`bin/dot_popper` finds the game as `File.expand_path("..", __dir__)`, so the
whole folder must ship beside it: `conf.rb`, `main.rb`, `lib/`, and
`assets/` (the Fredoka fonts and the four GLSL shaders). Every asset path is
relative to that folder and is read through Lota's filesystem, never through
the working directory. `$PROGRAM_NAME` is read only by the
`DOT_POPPER_SMOKE` check, which is for CI runners and is never set on iOS.

The bundle identifier is `com.kerricklong.DotPopper` (`fledge.yml`).

## What the iOS app needs

| Need | Choice | Why |
| --- | --- | --- |
| Lota | Trunk at 04d5b11 or later, not 0.1.2 | Only trunk builds for iOS, and only trunk calls `Lota.touchpressed`. 0.1.2 has neither. The repository's `Gemfile` stays on 0.1.2, so the desktop builds and CI are unchanged |
| `t.highdpi` | `true` (already in `conf.rb`) | Without it LÖVE, and so Lota, draws at 1x on a Retina iPad |
| Orientations | All four on iPad (`UISupportedInterfaceOrientations~ipad`); portrait and both landscapes on iPhone | The field is the whole window and refits on every resize. `conf.rb`'s window is resizable, so SDL allows every orientation that Info.plist allows (`UIKit_GetSupportedOrientations`) |
| Multitasking | Leave `UIRequiresFullScreen` unset | Split View and Stage Manager resize the window, which the game handles as it handles a rotation |
| Status bar | Hidden: `UIStatusBarHidden` = `true` in Info.plist for the launch screen; the game hides it itself after launch | See "Fullscreen" below |
| Audio session | `AVAudioSessionCategoryAmbient`, set by the host before `SDL_RunApp` | See "Sound" below |
| Entitlements | None | No network, no iCloud, no Game Center, no camera or microphone. The save folder is the app's own container |
| `UIApplicationSupportsIndirectInputEvents` | `true` | SDL asks for it to see a mouse or trackpad on an iPad. The game takes clicks as taps |

## How the game behaves on iOS

`Shell::App#load` asks `Lota::System.os`, which answers `"iOS"` there
(LÖVE's `System::getOS`), and `DotSize.touch?` turns that into one flag.
Everything below is guarded by it or by Lota itself, so the desktop takes
exactly the paths it took before.

### Fullscreen and the safe area

On a desktop the game sizes its window to the play area. On a phone or
tablet it calls `Lota::Window.set_fullscreen(true, :desktop)` instead. SDL's
iOS window already covers the screen, so this changes no size. It hides the
status bar (`SDL_uikitviewcontroller.m`, `prefersStatusBarHidden`). It also
makes a swipe from the screen's edge need a second swipe before the system
takes it (`preferredScreenEdgesDeferringSystemGestures`), so a quick tap near
the home indicator stays a tap.

Dots use the whole screen, corners included. The score, the clock, the mute
button, the Daily and Share buttons, and every line of text stay inside
`Lota::Window.safe_area` (SDL's `SDL_GetWindowSafeArea`). If the safe area
comes back empty, the whole window stands in for it. On an iPad with Face
ID, with the status bar hidden, the bottom inset is for the home indicator.

### Rotation and resizing

A rotation, Split View, or a Stage Manager window is a `Lota.resize`. The
game then rebuilds the field and the layout, and every dot on screen is
moved back inside the new field (`Dot#confine`), mid-round included, so no
dot is left off screen. The rules never change: same radius, same speeds,
same clock. A portrait field is taller and narrower, which plays as the
field-size table in `doc/decisions.md` says. Fonts are remade for the new
size and density.

### Dot size

A dot's radius is 50 points, about 8 mm (`DotSize`), and the game prints
that when it starts. An iPad Pro 13-inch is 1032 × 1376 points, so a
portrait field is about 21 × 28 radii; an 11-inch iPad is about 17 × 24.

### Input

A finger is a `touchpressed` with device type `touchscreen`. SDL also makes
up a mouse press for each finger, with `istouch` true, which
`InputRouter` ignores, so one finger is one tap. A mouse or trackpad on an
iPad clicks as on a Mac. Every screen works by tap alone.

On iOS the keyboard does less. **M** still toggles the sound. **Escape**
does nothing, because an iOS app is left by the system, never by the app.
**F11** and **Alt+Enter** do nothing either, since the app is always
fullscreen.

### Sound

The sounds are synthesized when the game starts, so no MP3 or AAC decoder
is needed (Lota's iOS build has none). Audio goes through Apple's
`OpenAL.framework`, as in LÖVE's iOS build.

The audio session should be **Ambient**: it mixes with other apps' music
and stays quiet in silent mode, which suits a casual game. The game cannot
choose this itself. Lota does not apply `t.audio.mixwithsystem` yet, so the
session keeps iOS's default, SoloAmbient, which stops other apps' music.
LÖVE's own setting would not help either: it picks Playback
(`common/ios.mm`, `setAudioMixWithOthers`), which plays even in silent mode.
So the host's `main.m` should set the category before `SDL_RunApp`:

```objc
@import AVFoundation;
// in main, before SDL_RunApp:
[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
```

With no audio device, the game plays on without sound and prints a warning.

### Haptics

iOS gets none. LÖVE's `vibrate` on iOS ignores the length it is given and
plays the system's long vibration (`common/ios.mm`, `vibrate`). On an
iPhone, every pop would run into the next one. An iPad has no vibration
motor anyway. So `Shell::Haptics.for` buzzes only on Android. A real tap on
iOS would need `UIImpactFeedbackGenerator`, which neither LÖVE nor Lota
exposes.

### Share

Share copies the Daily's result with `Lota::System.clipboard_text=`, which
SDL turns into `UIPasteboard` on iOS. Writing to the pasteboard needs no
permission. If the copy fails, the game prints a warning and goes on.

### Files the game writes

Fused, the save folder is `Library/Application Support/dot_popper` in the
app's data container. iOS keeps it across launches and updates, and backs
it up. Every read and write goes through `Lota::Filesystem` (`SaveFile`),
and a failure loses the value, never the game.

| File | Holds |
| --- | --- |
| `best_score.txt` | The best score |
| `daily_best.txt` | Today's date and the day's best Daily score |
| `sound.txt` | `muted` or `on` |
| `taught.txt` | Present once the popped-dot hint has been shown |
| `rounds.csv` | The playtest log, one line per finished round (README, "Playtest log") |
| `shot-N.png` | Only when `DOT_POPPER_SHOTS` asks for screenshots |

In the Simulator the container is at
`$(xcrun simctl get_app_container "$UDID" com.kerricklong.DotPopper data)`.
On a device, Xcode's Devices window can download the container (Window >
Devices and Simulators, select the app, then the gear menu > Download
Container).

### Output

`puts` and `warn` go to the app's standard output and standard error.
Fledge's iOS runtime forwards both to the unified log, under the subsystem
`com.kerricklong.DotPopper`, category `ruby`. The host logs its exit status
under category `app`.

**Leave `OS_ACTIVITY_DT_MODE` unset**, with any value, `NO` included, in
Xcode's scheme and in `simctl launch`'s environment. With it set, the log
copies each entry back to standard error. On Fledge 0.4.0's runtimes, the
app then freezes in a loop of its own output and draws nothing (Fledge's
`doc/contributors/device-test.md`, step 4, and ADR 011, section 5).

### Environment variables

The development settings in `README.md` are read from `ENV`. A home-screen
launch has none of them, so the game plays normally.
`xcrun simctl launch` passes each `SIMCTL_CHILD_NAME=value` to the app as
`NAME=value`.

## Proving a good run in the Simulator

With the app built for the Simulator and installed on a booted iPad (`$UDID`):

```sh
SIMCTL_CHILD_DOT_POPPER_AUTOPLAY=1 SIMCTL_CHILD_DOT_POPPER_SEED=7 \
SIMCTL_CHILD_DOT_POPPER_QUIT_AFTER=45 SIMCTL_CHILD_DOT_POPPER_SHOTS=3,12,25,38 \
  xcrun simctl launch "$UDID" com.kerricklong.DotPopper
sleep 60
xcrun simctl spawn "$UDID" log show --last 2m --info --style compact \
  --predicate 'subsystem == "com.kerricklong.DotPopper"'
```

A good run logs these lines in this order, under category `ruby`.
`<data>` is the app's data container:

```
Dot Popper: a dot's radius is 50 points, about 8 mm
Dot Popper: each round is logged in <data>/Library/Application Support/dot_popper/rounds.csv
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-1.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-2.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-3.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-4.png
```

Then, under category `app`, the host's line that the app exited with
status 0. The same command on a Mac (`bundle exec lota run .` with those
variables) printed the same six lines, with "50 logical pixels" and
`~/Library/Application Support/Lota/dot_popper`.

Each of these lines means something went wrong, though the game still
runs:

| Line | Meaning |
| --- | --- |
| `a dot's radius is 50 logical pixels` | `Lota::System.os` did not answer `iOS`, so the game took the desktop's paths |
| `drawing without shaders`, or `drawing <name> without its shader (...)` | A GLSL shader failed to translate to Metal. Dots are drawn plainly |
| `drawing without the glow (...)` | No canvas for the bloom |
| `playing without sound (...)` | No OpenAL device |
| `using Lota's own font (...)` | `assets/fonts` did not ship |
| `could not save <file>` or `could not read <file>` | The save folder is not writable |
| Any line repeated, nested inside itself | `OS_ACTIVITY_DT_MODE` reached the app |

The four screenshots, at game-time seconds 3, 12, 25, and 38, show:

- 3: the first round, a few seconds in, with dots and the HUD (the bot
  starts at once)
- 12 and 25: the round, with popped dots crowding
- 38: Game Over, "Time!" with the score and the pile of dots

Check each one:

- It fills the screen, with no status bar and no letterboxing.
- The score pill sits below the top inset, and the mute button sits above
  the home indicator.
- A dot is about the size of a fingertip: its diameter is about a tenth of
  the screen's short side (100 of 1032 points on a 13-inch iPad).
- Text is sharp, which means `highdpi` is on.

Scores differ from the Mac's: the same seed on a different field size draws
different dots.

## On a real iPad

Signing with an Apple ID and installing follow Fledge's
`doc/contributors/device-test.md`, section 3, with the project `fledge build
ios` writes for this game in place of `SdlPhone-ios`. A free Apple ID's
profile lasts 7 days. Keep `OS_ACTIVITY_DT_MODE` out of the scheme (step 4).

## Unverified

- Nothing above has run on iOS. The behaviour comes from reading LÖVE's
  iOS code, SDL 3.4.10's UIKit backend, Lota trunk, and Fledge's
  device-test runbook.
- Whether `set_fullscreen` on iOS sends a `resize`, and whether the safe
  area changes when the status bar hides. The game handles either.
- Whether LÖVE's touch coordinates on a Retina iPad are in the same units
  as `Lota::Graphics.dimensions`, as they should be with `usedpiscale`
  on. The bot's taps go straight to the game and skip touch input, so only a
  real finger (or a click in the Simulator's window) tests it: a tap on a
  dot that does nothing is a mismatch.
- Whether the four shaders translate to Metal. If they do not, the game
  falls back as the table above says.
- Whether Apple's deprecated `OpenAL.framework` still plays on iPadOS 26
  and 27.
