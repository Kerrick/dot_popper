# Dot Popper on an iPad

This page describes the game's side of an iOS or iPadOS build: what the app needs, what the game does differently there, and how to tell a good run from a bad one.

The app itself isn't built in this repository. It is built by the iOS route of Lota's phone guide (`doc/guide/phones.md`, at Lota's `v0.2.2` tag), with Lota's experimental iOS engine and Lota's iOS host, and with Fledge's `fledge build ios` command, which generates an Xcode project. The desktop builds and CI don't use it.

## Where things stand

- **Dot Popper builds its own kit.** The [Kits workflow](../.github/workflows/kits.yml) builds `dot-popper-ipad-kit.zip` on every `v*` tag and by hand, from Lota's `v0.2.2` tag and Fledge v0.6.0, with Lota's iOS host and Dot Popper's two changes to it in `ios/host` (PACKAGING.md, "The iPad and iPhone kit"). The project targets iPhone and iPad. Earlier kits, built by a Lota agent from Lota's experiment branches, are retired.
- **It runs in the Simulator.** A fresh runner builds the kit's project for the Simulator and, unsigned, for devices, and the autoplay bot plays it to the end in an iPad Pro 13-inch Simulator with exit status 0, with all four shaders, the fonts, the pile at Game Over, and the save folder working.
- **It hasn't run on a real iPad or iPhone.** Nobody has yet signed it, installed it, or played it on hardware. See "What is still unverified" at the end.

## The program

The app's program is `bin/dot_popper`, the same launcher the desktop builds use (it is listed under `programs` in `fledge.yml`). It starts the repository's folder as a fused Lota game, meaning a standalone app rather than a development run. `main.rb` is *not* the program: it only defines the callbacks Lota calls, so an app that ran it directly would define them and exit at once.

`bin/dot_popper` finds the game in the folder above itself (`File.expand_path("..", __dir__)`), so the whole folder must ship beside it, including `conf.rb`, `main.rb`, `lib/`, and `assets/` (the Fredoka fonts and the four GLSL shaders). Every asset is read through Lota's filesystem by a path relative to that folder, never through the working directory. The only code that reads `$PROGRAM_NAME` is the `DOT_POPPER_SMOKE` build check, which CI uses on desktop builds and which is never set on iOS.

The bundle identifier is `com.kerricklong.DotPopper`, set in `fledge.yml`.

## What the iOS app needs

| Setting | Value | Why |
| --- | --- | --- |
| Lota | 0.2.2, built with its experimental iOS engine from a clone of its `v0.2.2` tag, with the iOS host its gem carries | Lota before 0.1.3 neither builds for iOS nor calls `Lota.touchpressed` for a touchscreen; 0.2.2 is the first release whose guide documents the phone route and ships the host |
| `t.highdpi` | `true`, already set in `conf.rb` | Without it, LÖVE, and so Lota, draws at 1× on a Retina iPad, and everything looks blurry |
| Orientations | All four on iPad (`UISupportedInterfaceOrientations~ipad`); portrait and both landscapes on iPhone | The field is the whole window and rebuilds itself whenever the window changes size. Because `conf.rb` makes the window resizable, SDL allows every orientation that Info.plist allows |
| Multitasking | Leave `UIRequiresFullScreen` unset | Split View and Stage Manager resize the window, which the game handles exactly as it handles a rotation |
| Status bar | Hidden: set `UIStatusBarHidden` to `true` in Info.plist for the launch screen; the game hides it itself after launch | See "Fullscreen and the safe area" |
| Audio session | `AVAudioSessionCategoryAmbient`, which Lota's host program sets before `SDL_RunApp` from its `Info.plist`'s `LotaAudioSessionCategory`, `ambient` | See "Sound" |
| Entitlements | None | The game uses no network, iCloud, Game Center, camera, or microphone, and saves only in the app's own container |
| `UIApplicationSupportsIndirectInputEvents` | `true` | SDL needs it to see a mouse or trackpad on an iPad. The game treats clicks as taps |

## How the game behaves on iOS

When the game starts, `Shell::App#load` asks `Lota::System.os` which system it is on. On iOS the answer is `"iOS"` (from LÖVE's `System::getOS`), and `DotSize.touch?` turns that into a single "this is a touch device" flag. Every difference described below depends on that flag or on Lota itself, so a desktop follows exactly the same code paths as before.

### Fullscreen and the safe area

On a desktop, the game sizes its window to fit the play area. On a phone or tablet it calls `Lota::Window.set_fullscreen(true, :desktop)` instead. SDL's iOS window already covers the whole screen, so this changes no sizes, but it does two useful things. It hides the status bar (through `prefersStatusBarHidden` in SDL's `SDL_uikitviewcontroller.m`). And it makes a swipe from the edge of the screen need a second swipe before iOS acts on it (through `preferredScreenEdgesDeferringSystemGestures`), so a quick tap near the home indicator stays a tap.

Dots use the whole screen, corners included. Everything else stays inside the safe area, the part of the screen that rounded corners, the camera housing, and the home indicator don't cover. That includes the score, the clock, the mute button, the Copy my result button, and every line of text. The game gets the safe area from `Lota::Window.safe_area` (SDL's `SDL_GetWindowSafeArea`). If that comes back empty, the game uses the whole window instead. On an iPad with Face ID, once the status bar is hidden, the safe area's bottom inset is there for the home indicator.

### Rotation and resizing

Rotating the iPad, entering Split View, or resizing a Stage Manager window all reach the game as a `Lota.resize` call. The game then rebuilds the field and the layout, and moves every dot in proportion to the new field (`Dot#refit`), even in the middle of a round: a dot 70% of the way across stays 70% of the way across, so turning a phone and back puts every dot back where it was, and no dot is ever left off screen. The heap of dots at Game Over is moved back inside the window.

The rules never change with the window: the radius, the speeds, and the clock stay the same. A portrait field is just taller and narrower, and plays as the field-size table in [decisions.md](decisions.md) predicts. Fonts are rebuilt for the new size and pixel density.

### Dot size

The standard dot's radius is 50 points, about 8 mm (see `DotSize`), and the game prints that when it starts. Unless the player chooses **Standard**, a round's dots are sized to the screen instead (README, "How big the dots are"): about 30 points on an iPhone 13 mini, 51 on an 11-inch iPad, and 61 on a 13-inch iPad Pro. An iPad Pro 13-inch is 1032 × 1376 points, so a portrait field there is about 21 × 28 radii. An 11-inch iPad's is about 17 × 24.

Once a round has been played, the title's **Dot size** control appears only where sizing the dots to the screen would change them by more than a tenth. On an iPad Pro 13-inch the fitted radius is about 61 points, so its first segment, **Fit the screen**, says "Bigger, less room" and its second, **Standard**, "Smaller, more room"; on an 11-inch iPad the fitted radius is about 51 points, so the two sizes look alike and the control is left out.

### Input

A finger on the screen reaches the game as a `touchpressed` call with the device type `touchscreen`. SDL also generates a mouse press for each finger, marked `istouch`, and `InputRouter` ignores those, so one finger makes exactly one tap. A mouse or trackpad connected to an iPad clicks just as on a Mac. Every screen in the game can be used by tapping alone.

The keyboard does less on iOS. **M** still turns sound on or off, **Enter** and **Space** press the screen's main button, and **Escape** goes back from the Records screen and on from Game Over, but never quits, because iOS apps are closed by the system, never by the app itself. **F11** and **Alt+Enter** do nothing either, since the app is always fullscreen.

A game controller paired with the iPad should play as it does on a computer, though nobody has tried one yet. SDL presents an iPad's accelerometer as a joystick too, but `Shell::Gamepads` keeps only joysticks that are gamepads, so the accelerometer is never one. An earlier version of the game asked Lota for the list of joysticks every frame, and on iOS that crashed the game in the Simulator; the game no longer asks, and Lota's development branch has fixed the cause. Lota's host program, which the kit uses, also turns off SDL's accelerometer joystick (`SDL_ACCELEROMETER_AS_JOYSTICK=0`), so the accelerometer is never even offered as one; a paired controller still is.

### Sound

The game synthesizes its sounds when it starts, so it needs no MP3 or AAC decoder (Lota's iOS build has none). Audio plays through Apple's `OpenAL.framework`, as in LÖVE's iOS build.

The audio session should use the Ambient category. Ambient audio mixes with music from other apps and goes quiet when the iPad is in silent mode, which suits a casual game. The game can't choose this itself, for two reasons. Lota doesn't apply LÖVE's `t.audio.mixwithsystem` setting yet, so the session keeps iOS's default category, SoloAmbient, which stops other apps' music. And LÖVE's own setting wouldn't help, because it chooses the Playback category (`setAudioMixWithOthers` in LÖVE's `common/ios.mm`), which keeps playing even in silent mode. So the host program's `main.m` sets the category before it calls `SDL_RunApp`, as Lota's host does from its `Info.plist`'s `LotaAudioSessionCategory`, whose `ambient` it ships with:

```objc
@import AVFoundation;
// in main, before SDL_RunApp:
[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
```

Lota's host program, which the kit uses, already does this. If no audio device is available, the game prints a warning and plays on without sound.

### Haptics

iOS gets no vibration. On iOS, LÖVE's `vibrate` ignores the length it is given and plays the system's long vibration (`vibrate` in `common/ios.mm`), so on an iPhone every pop's buzz would run into the next one. An iPad has no vibration motor anyway. So `Shell::Haptics.for` turns vibration on only for Android. A short tap on iOS would need Apple's `UIImpactFeedbackGenerator`, which neither LÖVE nor Lota exposes.

### Copy my result

On the Game Over screen, Copy my result copies the result with `Lota::System.clipboard_text=`, which SDL turns into a write to `UIPasteboard` on iOS. Writing to the pasteboard needs no permission. If the copy fails, the game prints a warning and carries on.

### Files the game writes

As a fused app, the game saves into `Library/Application Support/dot_popper` inside the app's data container. iOS keeps that folder across launches and updates, and includes it in backups. Every read and write goes through `Lota::Filesystem` (wrapped by `SaveFile`), and if one fails, only that value is lost; the game keeps running.

| File | What it holds |
| --- | --- |
| `best_score.txt` | The best score |
| `sound.txt` | `muted` or `on` |
| `taught.txt` | Present once the first-mistake hint has been shown |
| `rounds.csv` | The playtest log, one line per finished round (see "The playtest log" in the README) |
| `shot-N.png` | Screenshots, only when `DOT_POPPER_SHOTS` asks for them |

In the Simulator, this command prints the container's path:

```sh
xcrun simctl get_app_container "$UDID" com.kerricklong.DotPopper data
```

On a device, Xcode can download the container: choose Window > Devices and Simulators, select the iPad and then the app, and choose Download Container from the gear menu.

### Output

The game's `puts` and `warn` lines go to the app's standard output and standard error. Fledge's iOS runtime forwards both to the system's unified log, under the subsystem `com.kerricklong.DotPopper` and the category `ruby`. The host program logs the app's exit status under the category `app`.

**Leave `OS_ACTIVITY_DT_MODE` unset**, with any value, `NO` included, both in Xcode's scheme and in the environment `simctl launch` passes. When it is set, the system copies every log entry back to standard error. With Fledge 0.4.0's runtime, that standard error is forwarded to the log again, so the app freezes in a loop of its own output and draws nothing (see step 4 of Fledge's `doc/contributors/device-test.md`, and section 5 of its ADR 011). The kit's host program detects the variable and, when it is set, leaves the game's output on its own streams, but the safest course is to keep it out of the scheme.

### Environment variables

The developer settings listed in the README are read from the environment. An app launched from the Home Screen has none of them, so it plays normally. In the Simulator, `xcrun simctl launch` passes each `SIMCTL_CHILD_NAME=value` in its own environment to the app as `NAME=value`, which is how the check below sets them.

## Checking a run in the Simulator

With the app built for the Simulator and installed on a booted iPad Simulator whose identifier is in `$UDID`, run:

```sh
SIMCTL_CHILD_DOT_POPPER_AUTOPLAY=1 SIMCTL_CHILD_DOT_POPPER_SEED=7 \
SIMCTL_CHILD_DOT_POPPER_QUIT_AFTER=45 SIMCTL_CHILD_DOT_POPPER_SHOTS=3,12,25,38 \
  xcrun simctl launch "$UDID" com.kerricklong.DotPopper
sleep 60
xcrun simctl spawn "$UDID" log show --last 2m --info --style compact \
  --predicate 'subsystem == "com.kerricklong.DotPopper"'
```

This starts the autoplay bot with a fixed seed, takes four screenshots, quits after 45 seconds of play, and then prints the app's log.

### What a good run logs

A good run logs these lines, in this order, under the category `ruby`. Here `<data>` stands for the app's data container:

```
Dot Popper: a dot's radius is 50 points, about 8 mm
Dot Popper: renderer Metal 2.1 /  / Apple iOS simulator GPU
Dot Popper: screen 811x375 units, 2338x1080 pixels, dpi scale 2.88 (native 2.8793), safe area 49,0,711,355, mode 812x375 fullscreen desktop, usedpiscale true
Dot Popper: dots are sized to the screen as each round starts
Dot Popper: each round is logged in <data>/Library/Application Support/dot_popper/rounds.csv
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-1.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-2.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-3.png
Dot Popper: screenshot <data>/Library/Application Support/dot_popper/shot-4.png
```

After them, under the category `app`, the host program logs that the app exited with status 0. The renderer and screen lines are from an iPhone 13 mini Simulator turned landscape; the screen line comes again on every resize or turn. The same command run on a Mac (`bundle exec lota run .` with the same variables) printed the same lines, except that the first said "50 logical pixels", the renderer and screen were the Mac's, and the paths were under `~/Library/Application Support/Lota/dot_popper`.

### Diagnostic colours

The iPhone 13 mini playtest found a thin magenta strip at the right edge in landscape. To tell where such a strip comes from, set `DOT_POPPER_DIAGNOSTIC_COLORS=1` (in Xcode's scheme under Run > Arguments > Environment Variables, or as `SIMCTL_CHILD_DOT_POPPER_DIAGNOSTIC_COLORS=1` for `simctl launch`):

- The host program paints the window, its root view and the view's layer pure green behind SDL's view (without the variable, the night's ink, #0c0b22, so nothing pink or white can show behind the game).
- The game clears every frame to pure blue and draws no night behind the dots.

Then a **green** strip is a gap that SDL's view doesn't cover; a **blue** one is part of what the game draws to that its drawing leaves bare; and a strip still **pink** (or black) is in the drawable but outside anything the game's drawing, even its clear, reaches, which is LÖVE's or Lota's to look at.

In an iPhone 13 mini Simulator turned landscape, the drawable is 2338 pixels wide, Lota's dimensions 811 units at a scale of 2.88 (811.8 rounded down), and with the variable set the game's own screenshot is blue up to column 2335, but columns 2336 and 2337 stay black: not even the clear reaches them. Nothing green shows. Upright, columns 1078 and 1079 of 1080 do the same. So in the Simulator the strip lies inside the drawable, outside what LÖVE draws to; a real phone may leave those pixels a different colour.

The cause was LÖVE's Metal backend: it made the default stencil and depth buffers from the whole-unit width, 811 × 2.88 = 2336 pixels, and a Metal render pass is only as wide as its narrowest attachment, so nothing was drawn to the drawable's last two columns. Since `conf.rb` asks for neither buffer (`t.window.stencil = false`, `t.window.depth = false`), the same run from trunk, with the diagnostic colours, samples pure blue (0,0,255) at columns 2333 to 2337 of the game's own screenshot, on rows 108, 324, 540, 756 and 972 of 1080, and at columns 2335 to 2339 of `simctl io screenshot`'s 2340-pixel capture of the panel. No green shows anywhere: the layer stretches the 2338-pixel drawable over the panel's 2340.

### What a bad run logs

Each of these lines means something went wrong, although the game keeps running:

| Line | What it means |
| --- | --- |
| `a dot's radius is 50 logical pixels` | `Lota::System.os` didn't answer `iOS`, so the game took the desktop's code paths |
| `drawing without shaders`, or `drawing <name> without its shader (...)` | A GLSL shader failed to translate to Metal, so dots are drawn as plain shapes |
| `drawing without the glow (...)` | The glow beneath the dots couldn't get the offscreen canvas it draws into |
| `playing without sound (...)` | There is no OpenAL audio device |
| `using Lota's own font (...)` | The `assets/fonts` folder didn't ship with the app |
| `could not save <file>` or `could not read <file>` | The save folder isn't writable |
| Any line repeated inside itself | `OS_ACTIVITY_DT_MODE` reached the app |

### What the screenshots should show

The four screenshots are taken at 3, 12, 25, and 38 seconds of play:

- At 3 seconds, the first round has just begun, with dots and the score bar showing. (The bot starts a round right away.)
- At 12 and 25 seconds, the round is under way, with popped dots crowding the screen.
- At 38 seconds, the round is over: the Game Over heading, the score, and the dots in a heap.

In each one, check that:

- the game fills the screen, with no status bar and no black bars at the sides;
- the score bar sits below the top inset, and the mute button sits above the home indicator;
- a dot is about the size of a fingertip, with a diameter about a tenth of the screen's short side (100 of 1032 points on a 13-inch iPad);
- text is sharp, which shows that `highdpi` is on.

Scores will differ from a Mac's even with the same seed, because a different field size produces different dots.

## On a real iPad

The kit's `README.txt` gives the full steps: checking and unpacking the kit, signing it in Xcode with a free Apple ID's Personal Team, turning on Developer Mode on the iPad, checking the scheme, and running. Those steps follow section 3 of Fledge's `doc/contributors/device-test.md`, using the project `fledge build ios` writes for this game in place of Fledge's sample `SdlPhone-ios`. A free Apple ID's signing profile lasts 7 days, after which the app must be run from Xcode again. As above, keep `OS_ACTIVITY_DT_MODE` out of the scheme (step 4).

## What is still unverified

- **Running on a real iPad.** Everything above about devices comes from the Simulator runs and from reading LÖVE's iOS code, SDL 3.4.10's UIKit backend, Lota's iOS engine, and Fledge's device-test guide.
- **Touch coordinates on a Retina iPad.** They should be in the same units as `Lota::Graphics.dimensions` when `usedpiscale` is on. The bot's taps go straight to the game without passing through touch input, and the UI test's taps only started rounds, which a tap anywhere does. Only a real finger on a dot, or a click on a dot in the Simulator's window, tests it: if a tap on a dot does nothing, the units don't match.
- **Whether `set_fullscreen` on iOS sends a resize,** and whether the safe area changes when the status bar hides. The game handles either case.
- **Sound on a device.** Nobody has heard the game on an iPad, and Apple has deprecated `OpenAL.framework`, so it isn't certain that it still plays on iPadOS 26 and 27.
