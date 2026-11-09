# Packaging Dot Popper

Most players don't have Ruby installed, so Dot Popper also ships as a self-contained app. Lota's `lota fuse` command builds it, as LÖVE "fuses" a game into a program of its own. `lota fuse` writes a small project around the game and hands it to [Fledge](https://github.com/setdef/Fledge), which copies the game, Lota, and a copy of Ruby built to run from any folder into one directory, and then packs that directory into an archive and an installer. Every desktop app is built this one way, each on its own platform, since Fledge builds only for the computer it runs on.

Each platform's build produces two files:

| Platform | Files |
| --- | --- |
| Windows x64 | `Dot Popper-x64-mingw-ucrt.zip`, which holds `Dot Popper.exe`; and `Dot Popper-x64-mingw-ucrt-setup.exe`, an installer that doesn't need administrator rights |
| macOS on Apple silicon | `Dot Popper-arm64-darwin.dmg`; and `Dot Popper-arm64-darwin.tar.gz`, which holds `Dot Popper.app` |
| Linux x86_64, glibc 2.39 or newer (Ubuntu 24.04, Pop!_OS 24.04, Debian 13, Fedora 40) | a `.tar.gz` holding a `Dot Popper` folder with the program `Dot Popper` and a desktop entry; and an AppImage |

For playtesting, each device also has a **playtest kit**, which holds the app and a way to send back one file of results. See [Playtest kits](#playtest-kits).

## Getting a build

### From a release

Releases are on the [Releases page](https://github.com/setdef/dot_popper/releases), each with its apps and, from v0.8.2-rc.1 on, its playtest kits. GitHub marks them as prereleases, and it replaces the space in each file's name with a dot, so the Windows installer appears there as `Dot.Popper-x64-mingw-ucrt-setup.exe`.

### From any push to `trunk`

The [Package workflow](.github/workflows/package.yml) builds all three platforms on every push to `trunk`, so a build of the latest code is usually available:

1. Sign in to GitHub. Downloads from workflow runs require it.
2. Open the [Package workflow's runs](https://github.com/setdef/dot_popper/actions/workflows/package.yml) and choose a run with a green check mark.
3. At the bottom of the run's page, under Artifacts, download `dot-popper-windows-x64`, `dot-popper-macos-arm64`, or `dot-popper-linux-x86_64`. Each one is a `.zip` holding that platform's two files.

GitHub deletes artifacts after its retention period, which is 90 days by default.

### Installing on Windows

Run `Dot Popper-x64-mingw-ucrt-setup.exe`. It installs the game into `%LOCALAPPDATA%\Programs` and adds a Start menu shortcut. Alternatively, unpack `Dot Popper-x64-mingw-ucrt.zip` anywhere and run `Dot Popper.exe` from the unpacked folder.

The build isn't signed, so Windows SmartScreen warns about it the first time it runs. To run it anyway, choose **More info**, then **Run anyway**.

To uninstall, use Settings > Apps, or run `uninstall.exe` in the folder the game was installed to.

### Installing on macOS

Open the `.dmg` and copy `Dot Popper.app` to Applications, or anywhere you like. The app isn't notarized by Apple, so macOS stops it the first time. On macOS 14 or older, right-click it, choose **Open**, then confirm. On macOS 15 or newer, try to open it, then choose **Open Anyway** in System Settings > Privacy & Security.

### Installing on Linux

Unpack the `.tar.gz` anywhere and run `Dot Popper` in the folder it makes, or make the AppImage executable (`chmod +x`) and run it. Both need glibc 2.39 or newer, which Fledge's Linux runtime is built against.

### Where a packaged build saves its files

A packaged build saves the score record, the sound setting, and the playtest log in a `dot_popper` folder in the system's application-data folder: `%APPDATA%\dot_popper` on Windows, `~/Library/Application Support/dot_popper` on macOS, and `~/.local/share/dot_popper` (or `$XDG_DATA_HOME/dot_popper`) on Linux. The game prints the playtest log's full path when it starts. This is a different folder from the one `bundle exec lota run` uses, so a packaged build and a development run keep separate scores.

## Cutting a release

1. Set `version:` in `fledge.yml` to the new version.
2. Commit, and push the commit to `trunk`.
3. Tag the commit and push the tag. For example, for version 0.9.0:

   ```console
   $ git tag v0.9.0 && git push origin v0.9.0
   ```

Pushing a tag that starts with `v0.` makes the Package workflow attach the apps, and the Kits workflow the playtest kits, to a new prerelease for that tag. A tag with a suffix, such as `v0.8.2-rc.1`, works the same way, which is how to try a release's kits before the release itself.

## How the build is put together

### `lota fuse`

CI runs, on each platform's runner (`.github/actions/fuse`):

```console
$ gem install --local vendor/cache/lota-0.3.0-PLATFORM.gem
$ lota fuse . --identifier com.setdef.DotPopper --app-version VERSION --icon icons/icon --out DIR
```

The first line installs Lota's release gem for the platform from `vendor/cache`, after checking its SHA-256 against the `SHA256SUMS` of [Lota's v0.3.0 release](https://github.com/setdef/Lota/releases/tag/v0.3.0). `lota fuse` ships that very gem file in the app. `VERSION` is the tag's version without its `v` when CI builds a tag, and `fledge.yml`'s `version:` otherwise, as for a build by hand. A release candidate builds its base version (`v0.8.2-rc.1` builds 0.8.2), since macOS, iOS, and Windows take only numbers there; the kit's header names the tag beside it, and the Kits workflow checks that it does (`script/playtest_kit.rb check-build`).

`lota fuse` reads the game's name ("Dot Popper", from `conf.rb`'s `t.window.title`) and its save folder's name (`t.identity`, `dot_popper`) without opening a window. It copies the game into `DIR/fuse-project/game/dot_popper`, leaving out `.git`, `.bundle`, and `vendor/cache`, and writes a Gemfile from the game's own, with Fledge v0.9.0, a `fledge.yml`, and an entry script that starts the game fused. It then runs `fledge build` in that project. Since Lota 0.2.2, `lota fuse` honors the game's `Gemfile` and `Gemfile.lock`: it ships the gems the lockfile locks, at those versions, and refuses a game whose lockfile is missing, doesn't lock the platform it builds for, or locks another version of Lota. Dot Popper's Gemfile asks only for Lota outside its development and test groups, so Lota's gem is all that ships. `lota fuse` also writes Lota's notices, `NOTICES.txt`, into the app's `app` folder, two folders above the game's (`Contents/Resources/app` on macOS), where the Credits screen finds them.

"Fused" is LÖVE's term for a game shipped as a standalone app. A fused game saves its files in a folder named after the game alone, as shipped LÖVE games do, where a development run under `lota run` saves into a `Lota` folder.

`lota fuse` needs the network, since Bundler fetches Fledge from GitHub and Fledge downloads its runtime the first time, and Git. On Windows, the app opens no console, so what the game prints goes nowhere, unless whatever starts it captures its output, as the Windows kit's `playtest.ps1` does. Ruby's YJIT isn't in RubyInstaller's Ruby, so the Windows app runs without it; elsewhere `lota fuse` turns it on.

### The launcher, `bin/dot_popper`, and `fledge.yml`

`bin/dot_popper` and the `programs:` entry in `fledge.yml` are what Fledge built from directly before `lota fuse` was released. The desktop builds no longer use them. The iOS build still does (see [The iPad and iPhone kit](#the-ipad-and-iphone-kit)), because `lota fuse` doesn't build for phones: Fledge's `fledge build ios` packages `bin/dot_popper`, which starts the game folder fused with `Lota::Boot.new(folder, ARGV, fused: true).call`. Its `DOT_POPPER_SMOKE` check mode, and `script/smoke-windows.ps1`, which ran it on a Windows build, belong to that older path. `fledge.yml` also holds the version every build takes.

### Lota's gems

Lota isn't on RubyGems.org, so its gems come from `vendor/cache`, and `Gemfile.lock` records the SHA-256 checksum of each platform's gem. When you update Lota, write each platform's checksum into the `CHECKSUMS` section of `Gemfile.lock` by hand, as Fledge's README explains under "A gem that only `vendor/cache` holds", and change `LOTA_VERSION` in both workflows.

### The icon

`script/make_icon.rb` draws the icon in code. It is all rights reserved (see `LICENSES/ICONS.md`).

### What goes into the app

The repository is copied into the app's `game/dot_popper` folder, except `.git`, `.bundle`, `vendor/cache`, and what `lota fuse --exclude` leaves out in `.github/actions/fuse`: tests, docs, signatures, scripts, the playtest kits, the phone hosts, and the repository's own files. A build by hand without those flags ships them too, which is harmless.

## Building on your own computer

You need Ruby 4.0.9, the version in `.ruby-version`, and Git. Each platform can build only its own app, so build the macOS app on a Mac, the Windows app on Windows, and the Linux app on Linux.

```console
$ gem install --local vendor/cache/lota-0.3.0-arm64-darwin.gem
$ lota fuse . --identifier com.setdef.DotPopper --app-version 0.8.1 --icon icons/icon
dist/Dot Popper-arm64-darwin.tar.gz
dist/Dot Popper-arm64-darwin.dmg
Built the app for arm64-darwin only. Run lota fuse on each platform you ship for.
```

Use the gem for your platform: `x64-mingw-ucrt` on Windows with RubyInstaller's Ruby, `x86_64-linux-gnu` on Linux. The first build downloads Fledge's Ruby runtime for your platform, which takes about a minute. The `dist/` folder is ignored by git.

## What CI checks

The [Package workflow](.github/workflows/package.yml) runs on every push to `trunk`, on every tag that starts with `v0.`, and when started by hand from GitHub's Actions page. It has five jobs:

- **Test**, on Ubuntu, runs `bundle exec rake test`.
- **Windows x64**, on `windows-latest`; **macOS arm64**, on `macos-15`; and **Linux x86_64**, on `ubuntu-24.04` (its glibc is 2.39, Fledge's Linux floor), each run `lota fuse`, unpack the app under a folder with a space in its name, play it with the autoplay bot for 20 seconds with no Ruby on its `PATH` and an all but empty environment, and upload the `dot-popper-windows-x64`, `dot-popper-macos-arm64`, or `dot-popper-linux-x86_64` artifact. GitHub's Windows and Linux runners have no graphics card, so the game draws there with Mesa's software OpenGL (llvmpipe): on Windows, Mesa's `opengl32.dll` from the runner's MSYS2 goes beside the program, and on Linux it draws on Xvfb. The run must exit with status 0 and print its frame rate. The Windows job then plays the app again allowed only Vulkan (`DOT_POPPER_RENDERERS=vulkan`), which the runner can't start, and checks that the game ran its own `Dot Popper.exe` again without Vulkan, drew with OpenGL, and exited with status 0 (doc/decisions.md, "When Vulkan can't start the game, it starts again without it").
- **Release** runs only for a `v0.` tag. It attaches the apps to a GitHub prerelease for the tag. It requires the Windows job to have passed. Nothing is published to RubyGems.

The [Kits workflow](.github/workflows/kits.yml), on `v*` tags and by hand, builds the playtest kits and attaches them to the tag's release too. The [Android workflow](.github/workflows/android.yml) does the same for the experimental Android kit. Both are described below.

## Playtest kits

The maintainer's rule for kits is **one kit in, one results file out, per device**. He opens one kit on a device, plays, and sends back one file, with nothing to coordinate between kits. On the maintainer's Mac, each tag's kits are unpacked into `/Users/Shared/dot-popper-kits/<tag>/<platform>/`, and each finished results file goes into `/Users/Shared/dot-popper-results/<device>/`. `/Users/Shared` is shared on purpose; the personal `Downloads` folder isn't used. The [Kits workflow](.github/workflows/kits.yml) builds them:

| Kit | Holds | Results file |
| --- | --- | --- |
| `dot-popper-windows-kit.zip` | The fused game in `Dot Popper/`, `playtest.ps1`, and `README.txt` | `dot-popper-results.txt`, which `playtest.ps1` writes beside itself |
| `dot-popper-macos-kit.zip` | `Dot Popper.app`, `README.txt`, and `macos-results.txt` | `macos-results.txt`, filled in by hand |
| `dot-popper-linux-kit.tar.gz` | The fused game in `Dot Popper/`, `playtest.sh`, and `README.txt` | `dot-popper-results.txt`, which `playtest.sh` writes beside itself |
| `dot-popper-ipad-kit.zip` (experimental) | The Xcode project in `DotPopper-ios/`, `README.txt`, `BUILD-INFO.txt`, and `ios-results.txt` (`ipad-results.txt` in older kits) | `ios-results.txt`, filled in by hand, one copy per iPhone or iPad |
| `dot-popper-android-kit.zip` (experimental, from the [Android workflow](.github/workflows/android.yml)) | `DotPopper-debug.apk`, `README.txt`, and `android-results.txt` | `android-results.txt`, filled in by hand |

### The questions, `playtest/checks.yml`

Every question a kit asks lives in [`playtest/checks.yml`](playtest/checks.yml), in the game's own words: a `desktop` list for Windows, macOS, and Linux, whose wording differs by system only where the keys or tools do (F11 or Command+Enter, Notepad or TextEdit), an `ios` list for iPhone and iPad, and an `android` list. `script/playtest_kit.rb` renders them into each kit: into `playtest.ps1` from `playtest/playtest.ps1`, into `playtest.sh` from `playtest/playtest.sh`, and into `macos-results.txt`, `ios-results.txt` (`ipad-results.txt` in older kits; `sheet ipad` still renders it, for the workflow that names it so), and `android-results.txt`. `test/playtest_kit_test.rb` checks that every check has wording and an answer on every system, and that each phrase a check quotes, such as "Copy my result" or "Standard", is one the game still shows. To read what a kit will ask, render it yourself:

```console
$ ruby script/playtest_kit.rb sheet ios /tmp/ios-results.txt
$ ruby script/playtest_kit.rb windows /tmp/playtest.ps1
```

The desktop list is the maintainer's 18 checks: sound and mute first (the mute check has the script quit and restart the game, to see that the mute is remembered), then edges, fullscreen, resizing, stereo panning, the bright dot's edge, the Dot size choice, Copy my result, Your records, sharp text, the Game Over pile, and overall feel; then, only for a player with a controller, 14 to 18: the cursor's smoothness and top speed, A, Start, X and B, and the pile with A and the right stick. The iOS list is his 13, worded for an iPhone or an iPad. The Android list is the iOS checks in a phone's words, plus a check of the buzzes, one of what Back does on each screen, one of leaving for the Home screen mid-game, and, in the crash check, the `adb logcat -d` command that keeps the log if the app closes at launch.

### The Windows kit

The player unzips the kit, right-clicks `playtest.ps1`, and chooses **Run with PowerShell**, which runs it with this process's execution policy bypassed. The script:

1. records this computer's Windows build, graphics card and driver, each display's size, refresh rate, and scale, sound devices, and controllers (XInput slots and Plug and Play devices);
2. asks whether a controller is connected, then starts the game with `DOT_POPPER_PERF=1`, its standard output and standard error captured;
3. asks the checks one at a time while the game runs, each with what to try, an answer (y / n / skip, a rating, or pasted text), and an optional note, and for check 2 waits for the player to quit and starts the game again;
4. asks the player to quit, then adds each session's output and the text files of `%APPDATA%\dot_popper` (`games.csv`, `lifetime.txt`, `best_score.txt`, and the rest);
5. tells the player, in plain words, where `dot-popper-results.txt` is and to send it back, and opens File Explorer on it.

The results file is written again after every answer, so a crash leaves what was recorded so far. A second run keeps the first one's file under another name. The script removes the download mark from the kit's files, so the game starts without a warning, changes no setting, and needs no administrator. It runs in Windows PowerShell 5.1 and PowerShell 7, and is kept in ASCII, since 5.1 reads a file without a byte order mark as ANSI. If the game freezes, Enter in the script's window closes it.

CI parses the rendered script in both PowerShells, then runs the kit as the maintainer would: unzipped into `Downloads` under a folder with a space, every file marked as downloaded, through `powershell.exe` with answers on standard input, and with Mesa beside the game in that copy only. `.github/kit_check.rb` writes the answers from `checks.yml` and then checks the results file: every check answered with its note, the pasted text, the restart for check 2, the system facts, the game's frame-rate lines, an exit status of 0, and the save folder.

### The Linux kit

`playtest.sh` works as `playtest.ps1` does, with the same checks. The player runs `./playtest.sh` in a terminal in the kit's folder. It records the distribution, kernel, desktop and session type (Wayland or X11), graphics card, OpenGL renderer and driver (with `glxinfo`, when `mesa-utils` is installed), displays and refresh rates (`xrandr`), GNOME's scale, the sound server, and controllers, and collects `~/.local/share/dot_popper`. CI runs it under Xvfb with Mesa, answers on standard input, and checks its results file as it checks Windows'. The kit is a `.tar.gz`, which keeps the program's executable bit.

### The macOS kit

The macOS kit holds the app, a README that explains opening an app that isn't notarized (right-click and Open on macOS 14 or older, Open Anyway in Privacy & Security on 15 or newer), and `macos-results.txt`, the desktop checks with a blank after each, to fill in. The README also shows how to record the frame rate from Terminal with `DOT_POPPER_PERF=1`, and where the save folder is. CI plays the app by itself for 30 seconds on `macos-15` before packing it.

### The iPad and iPhone kit

This kit is **experimental**, as Lota's phone route is. The Kits workflow takes the iOS route of Lota's guide, [Building a Game for iPhone, iPad, and Android](https://github.com/setdef/Lota/blob/v0.3.0/doc/guide/phones.md), at Lota's `v0.3.0` tag, with nothing from Lota's experiment branches:

1. clone Lota at its `v0.3.0` tag, with the `vendor/love` and `vendor/love-apple-dependencies` submodules;
2. in the clone, `bundle install` and `bundle exec rake ios:sdl3`, then build Lota's gem and unpack it into `tmp/phone/lota`, the folder of only what the gem packages, which the phone project names as its `lota` gem;
3. lay out the guide's phone project: the game's files in `game/dot_popper` (less what only the repository needs: tests, docs, CI, `ios/`, `android/`, and `vendor/`), a `main.rb` that loads its `bin/dot_popper`, Lota's iOS host from the gem in `host/ios` with Dot Popper's `ios/host` over it, a Gemfile with `gem "lota", path: <that folder>` and Fledge v0.10.0, and a `fledge.yml` with the name `DotPopper`, the identifier, the version, the icon, and `ios: host: host/ios`;
4. `bundle config set --local build.lota "--with-lota-source=... --with-lota-sdl3=.../tmp/ios/sdl3 --with-rice-dir=..."`, `bundle lock --add-platform ruby`, `bundle install`, and `bundle exec fledge build ios`.

Lota's iOS host already does most of what [doc/ios.md](doc/ios.md) asks: `Host/main.m` sets the audio session to Ambient (its `Info.plist`'s `LotaAudioSessionCategory`) before `SDL_RunApp` and sets `SDL_ACCELEROMETER_AS_JOYSTICK=0`; the status bar is hidden; every orientation is allowed on iPad; and the shared scheme sets no environment. `ios/host` holds only the files Dot Popper changes or adds over it: `Host/main.m`, which also paints the night's ink (#0c0b22) behind SDL's view and shows the system's share sheet for Share my score (doc/ios.md); `Host/Info.plist`, whose display name is "Dot Popper" and whose `NSPrincipalClass` is `main.m`'s `DotPopperApplication`; and `Host/PrivacyInfo.xcprivacy`, the App Store's privacy manifest, which Xcode bundles at the app's top level. The Simulator job builds the kit in Debug for the Simulator and for devices, and in Release for devices, and checks that each app carries the manifest. The project targets iPhone and iPad (`TARGETED_DEVICE_FAMILY` 1,2) on iOS 15 and later, arm64 only, so the same kit installs on an iPhone 12 mini or 13 mini as on an iPad.

The kit's README gives the free-Apple-ID steps: unzip with Finder (which keeps the frameworks' symbolic links), sign with a Personal Team, turn on Developer Mode, keep `OS_ACTIVITY_DT_MODE` out of the scheme, run, and trust the developer on the device. A free Personal Team signs for 7 days at a time and for 3 apps per device.

A second, fresh `macos-15` runner, with no Lota, Fledge, or bundle, unzips the kit, builds it with `xcodebuild` for the Simulator and, unsigned, for devices, installs it in an iPad Pro 13-inch Simulator, and runs the autoplay check from doc/ios.md: the log must say the dot's radius is 50 points, take four screenshots, and end with exit status 0. Its screenshots, log, and save folder are the `ci-results-ipad-simulator` artifact.

### The Android kit (experimental)

This kit is **experimental**, as Lota's phone route is. The [Android workflow](.github/workflows/android.yml) takes the Android route of the same guide at Lota's `v0.3.0` tag; by hand (workflow_dispatch) it takes another Lota tag or commit, to try an engine fix. It runs on `v*` tags and by hand, on `ubuntu-latest`:

1. clone Lota at `v0.3.0`, with the `vendor/love` submodule, and install its bundle;
2. install NDK r30 (`30.0.16248370`) and Java 21, then, in the clone, `bundle exec rake android:deps`, which builds LÖVE's libraries (zlib, Ogg, Vorbis, Theora, ModPlug, FreeType, HarfBuzz, and OpenAL Soft as a shared `libopenal.so`) and SDL 3.4.10 as `libSDL3.so`, for `arm64-v8a` and `x86_64`;
3. build Lota's gem and unpack it into `tmp/phone/lota`, as for iOS;
4. lay out the guide's phone project: the game in `game/dot_popper`, as for iOS, `android/android_kit` as its `main.rb`, Lota's Android host from the gem, which carries SDL's Java classes, in `host/android` with Dot Popper's `android/host` over it, OpenAL Soft's source archive in `sources/` from `rake android:notices`, a Gemfile naming the gem's folder and Fledge **v0.10.0**, and a `fledge.yml` with `android: host: host/android`;
5. `bundle exec fledge build android`, then `./gradlew assembleDebug` in the project it writes, and `./gradlew bundleRelease` for Google Play.

`android/host` holds the two files Dot Popper changes over Lota's host. `AndroidManifest.xml` makes two changes. It sets `SDL_ENV.SDL_ANDROID_TRAP_BACK_BUTTON` in its `<application>` meta-data, so Back reaches the game as Escape and Android does not close the app at once; Lota's `MainActivity` also registers an `OnBackInvokedCallback` on API 33 and newer when the manifest sets it, which takes Back's place under predictive back. The game then does what README.md says: Back leaves Your records for the title, leaves the app from the title, and does nothing during a game or at Game Over. And its activity's `configChanges` adds dark theme, font size, language, SIM, overlay changes (`assetsPaths`), and Display size (`density`) to Lota's turning and keyboards, since SDL ends the app whenever Android recreates its activity (doc/decisions.md). After a new Display size the game keeps the density it started with until its next launch, as LÖVE reads the dpi scale only once. `MainActivity.java` is Lota's, with five changes: `startActivity` hands the game's `dotpopper-store://` URLs to `ProStore.java`, beside it, for Play Billing, whose library is why `android/host` also carries Fledge's `build.gradle` and `gradle.properties`, with the dependency and AndroidX added (doc/decisions.md); a debuggable build takes environment variables as intent extras (below); `startActivity` turns the game's `dotpopper-share://` URL into Android's share sheet, a chooser over `ACTION_SEND` (doc/decisions.md); the window asks for the screen's fastest refresh rate at its resolution (`preferredDisplayModeId`), 120 Hz on a OnePlus Nord N30, which otherwise holds a game at 60; and `vibrate` starts each buzz on a thread of its own, since the vibrator service kept the game's thread waiting 1 to 5 ms a pop. `android/android_kit`, the spike's program, runs the game's `bin/dot_popper` unchanged; only when `DOT_POPPER_KIT_PROBE=1` is passed, as the emulator runs do, it also logs each key and touch with the state it arrives in, the game's events, and the frame the setdef splash is over by.

The APK's id is `com.setdef.DotPopper`, with minSdk 26 and targetSdk 36 (Fledge's Gradle template; the job checks both), code for `arm64-v8a` and `x86_64`, libraries aligned for 16 KB pages. It is a debug build, signed with a debug key Gradle makes fresh on each CI run, so installing a newer kit over an older one fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: `adb uninstall com.setdef.DotPopper` first. Being debuggable, it takes environment variables as intent extras, `am start --es lota.env.NAME VALUE`, which a launch from the app drawer never has. Sound is Lota's OpenAL Soft through OpenSL ES, on the media volume. Neither SDL's Java nor the host asks Android for audio focus (the job checks), so the game's sound plays alongside another app's music; the hand check asks whether it does.

A second job, on a fresh runner, unzips the kit, installs its APK on an `x86_64` emulator of API 33 (Android 13, as on a OnePlus Nord N30 5G), and runs [`.github/android_emulator_checks.sh`](.github/android_emulator_checks.sh), which drives [`.github/android_emulator.rb`](.github/android_emulator.rb) (the spike's driver, with two options added). Every run passes `--es lota.env.ALSOFT_DRIVERS null`. The first starts the bot with `DOT_POPPER_AUTOPLAY=1`, `DOT_POPPER_SEED=7`, and `DOT_POPPER_QUIT_AFTER=45`, presses Back 3 seconds into its first game and 1 second into its first Game Over, and requires the log to say "a dot's radius is 50 dp, about 8 mm", both Backs to arrive as Escape in `Playing` and `GameOver`, the game to carry on to the title, and the app to end with "exited with status 0". The second launches the game afresh, presses Back 1 second after the probe says the setdef splash is over (a key during the splash only skips it, and the splash's 3.5 seconds of the game's time can outlast more of the clock's on a slow runner), and requires the app to leave by itself with status 0. Its logcat, the game's lines, and screenshots are the `ci-results-android-emulator` artifact.

On the maintainer's Mac, the kit is unpacked into `/Users/Shared/dot-popper-kits/<ref>/android/`, and a blank `android-results.txt` waits in `/Users/Shared/dot-popper-results/oneplus-nord/`. The kit's README gives both ways to install: `adb install` with USB debugging on (which also gives a log), or opening the APK on the phone with "install unknown apps" allowed for the Files app.

## What has been verified, and what hasn't

These have been verified on CI's runners:

- `lota fuse` builds the Windows, macOS, and Linux apps from Lota 0.3.0's release gems, and each app plays itself with no Ruby on its `PATH` (Windows and Linux with Mesa's software OpenGL).
- The Windows kit's `playtest.ps1`, run from a downloaded, unzipped kit in Windows PowerShell 5.1 with answers on standard input, asks every check, restarts the game for check 2, captures the game's frame-rate output, collects `%APPDATA%\dot_popper`, and writes one complete `dot-popper-results.txt`. The Linux kit's `playtest.sh` does the same under Xvfb.
- The iPad kit is built from Lota's v0.3.0 tag, with Lota's iOS host, and Fledge v0.10.0, builds on a fresh Mac for the Simulator and, unsigned, for devices, and plays itself to the end in an iPad Simulator.
- The Android kit's APK, built from Lota's v0.3.0 tag by its phone guide, installs on an `x86_64` emulator of API 33 (a 320 × 640 dp screen, drawn by LÖVE's OpenGL ES renderer on SwiftShader; Android allowed only OpenGL ES until Lota fixed Vulkan's crash on backgrounding, see doc/decisions.md), plays itself for 45 seconds and exits with status 0, prints a radius of 50 dp, ignores Back during a game and at Game Over, and leaves the app on Back from the title ([run 42266401142](https://github.com/setdef/dot_popper/actions/runs/42266401142)).

These have not been verified:

- **Any kit on the maintainer's own devices**: real graphics cards and drivers, real sound, display scales above 100%, controllers, and the hand checks themselves, which only a person can answer.
- **The iPad and iPhone build on hardware.** Nobody has signed, installed, or played it on a device. See doc/ios.md, "What is still unverified".
- **The Android build on hardware, and its `arm64-v8a` code anywhere.** CI runs only the `x86_64` code, on an emulator. The maintainer's OnePlus Nord N30 5G will be the first run of the `arm64-v8a` code. Not checked on the emulator either: Back on Your records, a back *gesture* rather than the Back key, sound (the emulator runs with no audio), vibration, and tilt.
- **Restarting.** `lota run` restarts a game that calls `Lota::Event.restart`, but a fused game quits instead.
- **Signing.** The builds are unsigned, so SmartScreen and Gatekeeper warn about them, and the `.dmg` isn't notarized.
- **A computer with no usable graphics driver.** Fledge's own testing found that Lota then shows an error message box that begins with a Ruby backtrace, which a player would find confusing.
- **License notices.** The notices for Lota's bundled libraries, in the app's `notices/` folder, haven't been reviewed.
