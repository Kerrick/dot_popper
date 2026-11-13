<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Platforms

What differs between Windows, macOS, Linux, iOS and iPadOS, and Android: the window, the renderers and the Vulkan rescue, the lines the game prints as it starts, the iOS and Android host programs, the phones' notices, and the app identifier. It is for anyone changing the shell or a host, or building for a platform. How each build is made is in [PACKAGING.md](../../PACKAGING.md), and the game's side of an iOS build in [doc/ios.md](../ios.md); this page links to them rather than repeating them.

## At a glance

`Shell::App#load` asks `Lota::System.os` once, and `Shell::Platforms` turns its answer into the game's own `Platform` (`lib/dot_popper/platform.rb`), the one place Lota's name for a system is compared. Ruby's (`RUBY_PLATFORM`) is read only by the shell's renderer choice and relaunch, below. `test/platform_test.rb` fails if anything outside the shell names a system by either. Every difference below follows one of its questions:

| `Platform` | Means | True on |
| --- | --- | --- |
| `touch?` | A phone or tablet: played by touch, filling the screen, never quit or taken out of fullscreen from a keyboard | iOS, Android |
| `phone_host?` | The phone host catches the game's own URLs, for the share sheet and the store | iOS, Android |
| `quits_itself?` | The game may quit itself | every system but iOS |
| `buzzes?` | A pop and a mistake buzz | Android |
| `command_key?` | Shortcuts are held with Command, not Ctrl | macOS |
| `own_store` | The channel of the computer's own store, sold through the store helper | macOS (`mac-app-store`), Windows (`microsoft-store`) |
| `website_sales?` | A copy may sell through setdef's website | every system but iOS |

A system Lota names that `Shell::Platforms` doesn't know plays as a computer. What a graphics unit is called, for the printed dot size, is the engine's word, so it stays in the shell (`Shell::Platforms.unit`, which `Shell::Engine#unit` hands the composition root): "points" on iOS, "dp" on Android, "logical pixels" on a computer.

| | Windows | macOS | Linux | iOS and iPadOS | Android |
| --- | --- | --- | --- | --- | --- |
| Window | Sized to fit the desktop, resizable, with Settings' Display choice | as Windows | as Windows | Fills the screen | Fills the screen |
| Renderers (`RendererChoice.usual`) | LÖVE's order: Vulkan, then OpenGL | Metal | OpenGL only | Metal | LÖVE's order: Vulkan, then OpenGL ES |
| Vulkan rescue | Runs the game again | Never needed | Never needed | Never needed | Asks the player to start it again |
| Leaving the game | Quit on Home, Escape, B twice | as Windows | as Windows | Only the system | Back on Home, B twice |
| Haptics | None | None | None | None | A buzz on a pop and a mistake |
| Share my score | The game's preview | as Windows | as Windows | The system's share sheet | The system's share sheet |
| Starting input (`InputKind.starting`) | Mouse | Mouse | Mouse | Touch | Touch |
| Dot size reason printed | "50 logical pixels" | as Windows | as Windows | "50 points, about 8 mm" | "50 dp, about 8 mm" |

The standard dot is the same size on every platform ([rules.md](rules.md)). Selling Pro differs by build and store ([store-and-pro.md](store-and-pro.md), [ADR-0008](../adr/0008-native-features-live-outside-the-ruby-process.md), [ADR-0009](../adr/0009-the-store-is-a-port.md)), and so does sharing ([screens.md](screens.md)).

## Phones and tablets fill the screen

On a computer, the composition root has the engine size the window (`Shell::Engine#open_window`) to the play area `Style::WINDOW` names, fitted to the desktop, and Settings offers Window, Borderless and Full screen (`Shell::DesktopWindow`; [screens.md](screens.md)). On a phone or tablet, `Shell::Engine#fill_screen` calls `Lota::Window.set_fullscreen(true, :desktop)` instead, and the window control is `Presentation::NoWindowControl`, so Home has no Quit and Settings no Display. On iOS, fullscreen hides the status bar and makes a swipe from the screen's edge need a second swipe before the system acts on it, so a tap near the edge stays a tap. A game played with the whole screen shouldn't lose taps to system gestures. [doc/ios.md](../ios.md), "Fullscreen and the safe area", has the details.

**A phone's or tablet's keyboard never quits or leaves fullscreen.** `App#key_pressed` returns before Escape's quit and the fullscreen keys on a touch platform (`Platform#touch?`), since an iOS app never quits itself. What works before that point works on every device: M mutes, H opens How to play, Enter and Space press the screen's main button, Escape goes back where there is somewhere to go, and the keypad and scroll keys work ([input.md](input.md), "Keyboard").

**Leaving.** On Android, Escape (which Back arrives as) on Home quits (`Lota::Event.quit`). On iOS nothing quits (`Platform#quits_itself?`): B on Home neither asks nor quits (`App#leave_home`).

## What the game prints as it starts

Three lines, on standard output, let a run on a device be compared with another:

- `Dot Popper: a dot's radius is ...` (`DotSize#reason`, with the engine's name for a unit), as in the table above.
- `Dot Popper: renderer NAME VERSION / VENDOR / DEVICE` (`Shell::Engine#report_renderer`, from `Lota::Graphics.renderer_info`).
- `Dot Popper: screen ...` (`Shell::Engine#report_screen`, `Presentation::ScreenReport`), as it starts and again on every resize or turn. It gives the window's size in graphics units and in pixels, the dpi scale Lota reports and the display's native one, the safe area, and the window's mode with its `highdpi` and `usedpiscale` flags where Lota has them, for example `screen 812x375 units, 2436x1125 pixels, dpi scale 3.0 (native 3.0), safe area 47,0,718,354, mode 812x375 fullscreen desktop`. It lets a run on a real phone be set beside the Fledge SDL test program's on the same phone.

Lota's dimensions are whole units, rounded down, while the drawable may be a fraction of a unit wider (an iPhone 13 mini turned landscape: 2338 pixels at 2.88, 811.8 units, which Lota calls 811). So the night and the veils reach a unit past the dimensions (`Renderer#cover`), and each frame clears to the night's darkest ink (`Renderer#prepare`), so a pixel nothing draws is never black or another color. `conf.rb` asks for no stencil or depth buffer (`t.window.stencil = false`, `t.window.depth = false`): LÖVE's Metal backend sized those buffers from the whole-unit width, and a render pass is only as wide as its smallest buffer, which left the drawable's last two columns undrawn. [doc/ios.md](../ios.md), "Diagnostic colors", has the measurement and `DOT_POPPER_DIAGNOSTIC_COLORS`.

## Renderers

`conf.rb` decides which of LÖVE's renderers the game allows before the window opens, through `Shell::VulkanRescue.choose`, which asks `Shell::RendererChoice`. [ADR-0007](../adr/0007-renderers-per-platform-with-a-relaunch-without-vulkan.md) records why.

LÖVE tries its renderers in its own fixed order, Vulkan first wherever it may, whatever order a game lists. It falls back to the next only when a renderer cannot be created at all, not when Vulkan is created but finds no GPU it can use (a virtual machine, a remote desktop, old integrated graphics, Xvfb). Lota keeps LÖVE's behavior. So a game can put OpenGL first only by leaving Vulkan out.

| `RUBY_PLATFORM` | `RendererChoice.usual` | So LÖVE uses |
| --- | --- | --- |
| Linux (not Android) | `[:opengl]` | OpenGL |
| Windows | `nil`, LÖVE's own | Vulkan, then OpenGL |
| Android | `nil`, LÖVE's own | Vulkan, then OpenGL ES |
| macOS, iOS | `nil`, LÖVE's own | Metal, the only one |

- Windows allows Vulkan because, in fullscreen, OpenGL hides the Xbox Game Bar's overlay while it still takes the controller, and Vulkan shows it.
- Android's Vulkan relies on Lota's Android host holding `surfaceDestroyed` until the game's thread reports it has paused (`GameSurface` in `MainActivity`), without which Vulkan crashed whenever the game went to the background.
- `DOT_POPPER_RENDERERS=opengl` (or `vulkan`, or `metal`, comma-separated) replaces the list, to compare renderers on a device (`RendererChoice.asked`). `DOT_POPPER_NO_VULKAN=1` leaves Vulkan out, as after it failed. A store build still obeys both (`Build::HARMLESS`).
- `DOT_POPPER_FULLSCREEN=exclusive` makes the desktop's fullscreen LÖVE's exclusive one (`DesktopWindow`); the usual fullscreen is borderless.

**Every shader is optional.** If a shader fails to compile, `Shell::Pen` warns once ("drawing without shaders", or "drawing NAME without its shader (...)") and draws plain shapes, which keep bright and popped dots distinct. `DOT_POPPER_NO_SHADERS=1` forces this. A driver that rejects a shader shouldn't stop anyone from playing.

## The Vulkan rescue

When Vulkan fails to start the game, the game notes the day and runs itself again without Vulkan. The player sees one slower start, not an error.

| Part | What it does |
| --- | --- |
| `Shell::RendererChoice` | The renderers (`renderers` for `t.graphics.renderers`, `excluded` for `t.graphics.excluderenderers`), and whether Vulkan may be tried (`#vulkan_allowed?`) |
| `Shell::VulkanFailure` | The note: the day Vulkan failed, as an ISO date. It holds for 30 days (`LASTS`); `#retry_on` is the first day Vulkan is tried again. A clock set back keeps the note |
| `Shell::Relaunch` | The command that starts the game again as it first started, or nil where there is none |
| `Shell::VulkanRescue` | Carries them out from `conf.rb`, and tells LÖVE's failure to start a renderer from other errors by its words (`FAILED_START`, `.failed_start?`) |
| `conf.rb`'s `Lota.errorhandler` | Hands every error to `VulkanRescue#rescue` first, and to Lota's own error screen (`super`) when it answers nil |

The error handler lives in `conf.rb`, not `main.rb`, because the window opens before `main.rb` loads.

**Choosing.** `VulkanRescue.choose` first makes `t.identity` the save folder, since until `Lota.conf` returns Lota's save folder is the one named after the game's folder. It reads `vulkan_failed.txt` there. If the note holds, it prints `Dot Popper: Vulkan failed here on DAY, so it is left out until DAY`. Vulkan is left out when the note holds or `DOT_POPPER_NO_VULKAN=1` is set: the list loses `:vulkan` (or becomes LÖVE's own, if nothing is left), and `excluded` is `[:vulkan]`. `VulkanRescue#apply` writes the choice into `t.graphics`.

**Rescuing.** `#rescue` takes only a `RuntimeError` whose message matches `VulkanRescue::FAILED_START` ("Vulkan", "suitable GPU", "no supported renderer", or "Could not set window mode"), and only while Vulkan was allowed. Anything else goes to Lota's error screen. Once Vulkan is out, nothing is rescued, so the game never starts a third time. When it rescues, it:

1. warns `Dot Popper: Vulkan couldn't start the game (...), so it starts again without Vulkan`;
2. writes today's date to `vulkan_failed.txt` (`SaveFile`);
3. sets `DOT_POPPER_NO_VULKAN=1` in the environment, so the second run leaves Vulkan out even if the note could not be written;
4. closes the window if it is open, flushes both streams, and `exec`s `Relaunch#command`, never through a shell.

`Relaunch#command`:

| Where | Command |
| --- | --- |
| Under `lota run`, not fused | `RbConfig.ruby $0 run ARGV`: `$0` is lota's own program, which took `run` off `ARGV` |
| A fused macOS or Linux app | `RbConfig.ruby $0 ARGV`, which Fledge hands back to the app's launcher |
| A fused Windows app | The app's `NAME.exe`, two folders above the program Ruby runs (`ROOT\app\main.rb`), since Fledge's launcher sets the app's Ruby up; nil if that file isn't there |
| Android, iOS | nil |

On Windows, Ruby's `exec` runs the new process, waits for it, and exits with its status, so a script that waits for the game, such as `playtest.ps1` or CI, sees the real game end. Where there is no command, or `exec` fails, the game warns and shows one message box, "Dot Popper will use different graphics now. Please start it again." (`VulkanRescue::START_AGAIN`), and ends with status 1; the note makes the next start work. The rescue keeps its own relaunch rather than Lota's `"restart"`, since Lota's restart ends silently on a phone, where the rescue asks the player instead.

**The 30 days.** After them the game tries Vulkan again, and if it still fails, falls back again by itself. A driver update or a move from a virtual machine to real hardware can make Vulkan work, and the Xbox overlay is the reason Vulkan is allowed at all. Deleting `vulkan_failed.txt` tries sooner.

**Where it applies.** On Windows, a PC with a Vulkan driver but no GPU it can use. On Android, a Vulkan failure asks the player to start the game again. Linux allows no Vulkan, and Apple's systems have only Metal, so `#vulkan_allowed?` is false there unless `DOT_POPPER_RENDERERS` names Vulkan.

**Tests.** `test/shell/renderer_choice_test.rb` covers each platform's list, `DOT_POPPER_RENDERERS`, the note's 30 days, and each `Relaunch` command; `test/shell/vulkan_rescue_test.rb` which errors are rescued. The Package workflow's Windows job (`.github/workflows/package.yml`, "Vulkan alone") plays the fused app with `DOT_POPPER_RENDERERS=vulkan` on a runner with no GPU, and requires that it starts again without Vulkan, draws with OpenGL, writes the note, and exits with 0.

## The iOS host

The iOS app is built by the iOS route of Lota's phone guide, with Lota's iOS host from the gem and Dot Popper's `ios/host` laid over it ([PACKAGING.md](../../PACKAGING.md), "The iPad and iPhone kit"; [doc/ios.md](../ios.md)). `ios/host/Host` holds:

| File | What it changes over Lota's host |
| --- | --- |
| `main.m` | Lota 0.3.1's `main.m`, with four additions: the color behind SDL's view, the share sheet, the orientation override, and the store |
| `Info.plist` | Lota 0.3.1's, with the display name "Dot Popper" and `NSPrincipalClass` `DotPopperApplication` |
| `PrivacyInfo.xcprivacy` | The App Store's privacy manifest, in place of Fledge's |
| `Store.swift` | `DotPopperStore`, StoreKit 2's half of buying Pro ([store-and-pro.md](store-and-pro.md)) |

Lota's host already sets the audio session to Ambient (Info.plist's `LotaAudioSessionCategory`, `ambient`), sets `SDL_ACCELEROMETER_AS_JOYSTICK=0`, hides the status bar, and leaves the app's output on its own streams when `OS_ACTIVITY_DT_MODE` is set.

**The ink behind SDL's view.** As each window becomes key or visible, `main.m` paints SDL's window (the one that draws with Metal), its root view and the view's layer the night's ink, #0c0b22, so nothing pink or white can show behind the game. With `DOT_POPPER_DIAGNOSTIC_COLORS` set it paints pure green. Other windows are left alone: on an iPad, iOS shows windows of its own above SDL's, and one painted opaque hid the game.

**`DotPopperApplication`** is the app's `UIApplication`, a subclass of Lota's `LotaApplication`, named by Info.plist's `NSPrincipalClass`, since `SDL_RunApp` passes `UIApplicationMain` no class of its own.

- **Orientation.** SDL 3.4.10 reads the screen's orientation only from `statusBarOrientation`, and iOS 27 answers Unknown there, which SDL takes for portrait, so a landscape game drew tall and cut off. `DotPopperApplication#statusBarOrientation` answers the first connected window scene's `interfaceOrientation`. Only when no window scene is connected does it fall back on Lota's, which answers from the scene's geometry, or the scene's or screen's shape, where UIKit answers Unknown. Dot Popper's override is the one that fixed a landscape game on a real iPad with iPadOS 27; it stays in front of Lota's until an iPad shows Lota's alone gives a landscape game a landscape window.
- **URLs.** It catches the game's `dotpopper-share:` URLs (the share sheet) and `dotpopper-store:` URLs (the store) in `canOpenURL:` and `openURL:options:completionHandler:`, so they never leave the app ([ADR-0008](../adr/0008-native-features-live-outside-the-ruby-process.md); [doc/ios.md](../ios.md), "Share my score").

**Info.plist** allows portrait and both landscapes on an iPhone and all four orientations on an iPad, leaves `UIRequiresFullScreen` unset so iPadOS may show the game beside other apps, and sets `UIApplicationSupportsIndirectInputEvents` for a mouse or trackpad. [doc/ios.md](../ios.md), "What the iOS app needs", has why for each.

**The privacy manifest** (`PrivacyInfo.xcprivacy`) declares no tracking, the collected data types that `doc/privacy.json` lists ([privacy.md](privacy.md)), and two required-reason APIs: FileTimestamp (C617.1) and SystemBootTime (35F9.1). Those two are what Lota's audit of what the iOS app links (LÖVE, SDL, the prebuilt libraries, Lota's host, Fledge's runtime) found, and what Fledge's template declares; this file replaces Fledge's whole, so it keeps both. Dot Popper's own code uses neither DiskSpace nor UserDefaults: it saves through `Lota::Filesystem` read, write, remove and `info`, never shows a file date, and asks for no free space or user defaults. Declaring a reason the app doesn't use is inaccurate. SDL's read of `com.apple.swipescrolldirection` goes through CFPreferences, which is not on Apple's list. App Store Connect's validation has the last word. If it asks, the entries to add are DiskSpace (E174.1) or UserDefaults (CA92.1); DDA9.1 belongs only if the game ever shows file dates, and 3B52.1 only if the app declares document types or a file picker. `test/privacy` checks the manifest against `doc/privacy.json`.

## The Android host

The Android app is built by the Android route of Lota's phone guide, with Lota's Android host from the gem and Dot Popper's `android/host` laid over it ([PACKAGING.md](../../PACKAGING.md), "The Android kit"). `android/host` holds:

| File | What it changes over Lota's host or Fledge's template |
| --- | --- |
| `src/main/AndroidManifest.xml` | Traps Back, and handles more configuration changes |
| `src/main/java/org/setdef/fledge/host/MainActivity.java` | Lota 0.3.1's, with five changes: `lota.env` extras, the share sheet, the fastest refresh rate, vibrating on a thread of its own, and the store |
| `src/main/java/org/setdef/fledge/host/ProStore.java` | Play Billing's half of buying Pro ([store-and-pro.md](store-and-pro.md)) |
| `build.gradle`, `gradle.properties` | Fledge's, with Play Billing's library and AndroidX added |

**Back is trapped.** The manifest's `<application>` meta-data sets `SDL_ENV.SDL_ANDROID_TRAP_BACK_BUTTON` to 1. SDL then sends Back to the game as Escape and does nothing else, and on API 33 and newer Lota's `MainActivity#trapPredictiveBack` registers an empty `OnBackInvokedCallback`, which takes the system's place under predictive back. Without the trap, SDL sends Escape and then lets Back through, and Android closes the app at once, so Back in a game would throw it away. The game decides what Escape does ([input.md](input.md), "Keyboard"): back or Home where there is somewhere to go, including Home from Game Over, leaving the app from Home, and nothing during a game. The emulator check (`.github/android_emulator_checks.sh`) presses Back during the bot's first game and at its first Game Over, and requires the game to carry on to Home; and presses Back on Home and requires the app to leave with status 0.

**Configuration changes don't end the game.** SDL cannot survive its activity being made again: `onDestroy` quits the game, and the new activity's `onCreate` exits. So the activity's `android:configChanges` lists every change a player or the system can make while the game runs: `orientation|screenSize|smallestScreenSize|screenLayout|keyboard|keyboardHidden|navigation|uiMode|fontScale|fontWeightAdjustment|locale|layoutDirection|assetsPaths|density|grammaticalGender|mcc|mnc|touchscreen|colorMode`. Dot Popper adds `grammaticalGender`, `mcc`, `mnc`, `touchscreen` and `colorMode` to Lota's list. A player who switches on dark theme mid-game, or whose phone does it at sunset, shouldn't lose the game and the app; an overlay update (`assetsPaths`), which Android also applies to a just-installed app and when a wallpaper's colors change, likewise. `test/android_manifest_test.rb` checks the list and the Back trap.

**A new Display size keeps the launch density.** With `density` listed, a new Display size reaches SDL's `onConfigurationChanged` and the game carries on at the density it started with: LÖVE reads the dpi scale once, the window's pixel size doesn't change, so no `Lota.resize` arrives, and every drawing and hit area keeps that one scale. The new size applies from the next launch. The game keeps the safe area it measured at launch. If Lota or LÖVE ever report a changed dpi scale while running, `App#resize` already re-reads the scale, fonts and safe area.

**The fastest refresh rate.** `MainActivity#preferFastestRefresh` sets the window's `preferredDisplayModeId` to the fastest mode at the screen's present resolution, such as 120 Hz, where some makers otherwise hold a game's surface at 60. The game draws with vsync, so it then draws a frame for every refresh. The system still decides: battery saver, the player's own refresh rate setting, and the maker's rules can each hold it slower. Nothing plays faster at 120: the rules, the pile's physics, the particles and the tilt are timed in seconds, and `Rules::LONGEST_FRAME` caps a frame. On a OnePlus Nord, measured with the bot playing on OpenGL ES, the game drew 120 frames a second at 120 Hz, and a frame of a game took it about 3 ms; that was measured, not enforced.

**A buzz never holds up the frame.** LÖVE calls `MainActivity#vibrate` on the game's thread, and `Vibrator.vibrate` waits for the system's vibrator service (1 to 5 ms a pop, measured on a OnePlus Nord). So `vibrate` hands each buzz to a single thread of its own (`buzzer`), which keeps them in order.

**`lota.env` extras.** In a debuggable build only, each string extra of the launching intent named `lota.env.NAME` sets the environment variable `NAME` before Ruby starts, so the emulator checks can pass the game its settings with `am start --es`. A launch from the app drawer has none. Lota's host has no such way in, so it stays Dot Popper's addition.

**The share sheet and the store.** `MainActivity#startActivity` catches the game's `dotpopper-store:` URLs, for `ProStore`, and `dotpopper-share:` URLs, for a chooser over `ACTION_SEND`, so neither leaves the app ([ADR-0008](../adr/0008-native-features-live-outside-the-ruby-process.md)).

## Haptics

Only Android buzzes. `Shell::Haptics.for` gives a `Haptics`, which calls `Lota::System.vibrate`, on Android (`Platform#buzzes?`), and `Presentation::NoHaptics`, which does nothing, everywhere else. On iOS, LÖVE ignores the length it is given and plays the system's long vibration (`common/ios.mm`), so each pop's buzz would run into the next, and an iPad has no motor. A short tap on iOS would need `UIImpactFeedbackGenerator`, which neither LÖVE nor Lota exposes. A device that cannot buzz is no reason to stop the game: a failed buzz only warns. The lengths are `Style::HAPTICS` (15 ms for a pop, 40 ms for a mistake); [look-and-sound.md](look-and-sound.md) has when each plays. `test/presentation/show_test.rb` checks the buzzes the Show asks for.

## The phones' notices

Lota's rake tasks write each phone app's `NOTICES.txt`, which Credits shows (`Shell::NoticeFiles`), at the phone project's top, two folders above the game:

- `rake ios:notices[PROJECT]`, in the Kits workflow (`.github/workflows/kits.yml`). Apple's OpenAL needs no notice, so there is no LGPL text or source. The Simulator job checks that each app carries `NOTICES.txt` with FreeType's credit and the AGPL text, and no OpenAL Soft.
- `rake android:notices[PROJECT]`, in the Android workflow (`.github/workflows/android.yml`), which also copies OpenAL Soft's source archive into the project's `sources/`, as its LGPL asks. The workflow checks that the app's files carry `NOTICES.txt` with OpenAL Soft, FreeType's credit and the LGPL text, and the source archive beside it.

The desktop apps' notices come from `lota fuse` ([PACKAGING.md](../../PACKAGING.md)).

## The app identifier

Every build's identifier is `com.setdef.DotPopper`: the macOS and iOS bundle identifier and the Android application id, from `fledge.yml`'s `identifier` and the workflows' `IDENTIFIER`. The MSIX identity's placeholder is `setdef.DotPopper` (`MSIX_IDENTITY_NAME`'s default in `package.yml`), until it is copied from Partner Center. Pro's product id is `com.setdef.dotpopper.pro`. The save folder's name, `t.identity`, is `dot_popper` (`DOT_POPPER_SAVE_AS` gives a test run its own). setdef is the maker a player or a store sees, and an identifier can't change once a store knows the app. On iOS and Android each app's files live under its identifier, so a build under another identifier is a separate app with its own saves.
