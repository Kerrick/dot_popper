# Packaging Dot Popper

Most players don't have Ruby installed, so Dot Popper also ships as a self-contained app. [Fledge](https://github.com/setdef/Fledge) builds it. Fledge copies the game, the gems it uses, and a copy of Ruby built to run from any folder into one directory, and then packs that directory into an archive and an installer.

Each platform's build produces two files:

| Platform | Files |
| --- | --- |
| Windows x64 | `Dot Popper-x64-mingw-ucrt.zip`, which holds `Dot Popper.exe`; and `Dot Popper-x64-mingw-ucrt-setup.exe`, an installer that doesn't need administrator rights |
| macOS on Apple silicon | `Dot Popper-arm64-darwin.dmg`; and `Dot Popper-arm64-darwin.tar.gz`, which holds `Dot Popper.app` |

## Getting a build

### From a release

Releases v0.1.0 through v0.5.2 are on the [Releases page](https://github.com/Kerrick/dot_popper/releases), each with its Windows and macOS builds. GitHub marks them as prereleases, and it replaces the space in each file's name with a dot, so the Windows installer appears there as `Dot.Popper-x64-mingw-ucrt-setup.exe`.

### From any push to `trunk`

The [Package workflow](.github/workflows/package.yml) builds both platforms on every push to `trunk`, so a build of the latest code is usually available:

1. Sign in to GitHub. Downloads from workflow runs require it.
2. Open the [Package workflow's runs](https://github.com/Kerrick/dot_popper/actions/workflows/package.yml) and choose a run with a green check mark.
3. At the bottom of the run's page, under Artifacts, download `dot-popper-windows-x64` or `dot-popper-macos-arm64`. Each one is a `.zip` holding that platform's two files.

GitHub deletes artifacts after its retention period, which is 90 days by default.

### Installing on Windows

Run `Dot Popper-x64-mingw-ucrt-setup.exe`. It installs the game into `%LOCALAPPDATA%\Programs` and adds a Start menu shortcut. Alternatively, unpack `Dot Popper-x64-mingw-ucrt.zip` anywhere and run `Dot Popper.exe` from the unpacked folder.

The build isn't signed, so Windows SmartScreen warns about it the first time it runs. To run it anyway, choose **More info**, then **Run anyway**.

To uninstall, use Settings > Apps, or run `uninstall.exe` in the folder the game was installed to.

### Installing on macOS

Open the `.dmg` and copy `Dot Popper.app` to Applications, or anywhere you like. The app isn't notarized by Apple, so the first time, right-click it and choose **Open**, then confirm.

### Where a packaged build saves its files

A packaged build saves the best score, the sound setting, and the playtest log in a `dot_popper` folder in the system's application-data folder: `%APPDATA%\dot_popper` on Windows, and `~/Library/Application Support/dot_popper` on macOS. The game prints the playtest log's full path when it starts. This is a different folder from the one `bundle exec lota run` uses, so a packaged build and a development run keep separate scores.

## Cutting a release

1. Set `version:` in `fledge.yml` to the new version.
2. Commit, and push the commit to `trunk`.
3. Tag the commit and push the tag. For example, for version 0.6.0:

   ```console
   $ git tag v0.6.0 && git push origin v0.6.0
   ```

Pushing a tag that starts with `v0.` makes the Package workflow attach both builds to a new prerelease for that tag.

## How the build is put together

### The launcher, `bin/dot_popper`

The program Fledge packages is `bin/dot_popper`, not `main.rb`. The game's `main.rb` only defines the callbacks Lota calls, so running it directly would define them and then exit. The launcher instead starts the repository's folder as a *fused* Lota game, with `Lota::Boot.new(folder, ARGV, fused: true).call`. "Fused" is LÖVE's term for a game shipped as a standalone app.

A fused game saves its files in a folder named after the game alone, as shipped LÖVE games do. A development run under `lota run` saves into a `Lota` folder instead. Running `bundle exec lota run` from the repository's root works as before and never uses the launcher.

### The settings, `fledge.yml`

`fledge.yml` lists the launcher under `programs`, so a plain `fledge build` packages it rather than `main.rb`. The file also sets the app's name, its identifier (`com.kerricklong.DotPopper`), its version, the publisher, the icon, and the installers to build (`dmg` for macOS and `nsis` for Windows).

### Fledge itself

Fledge is in the `Gemfile`'s `development` group, so it isn't packaged into the app. It is pinned to its `v0.5.0` release. Earlier releases refuse Lota's Windows gem, because that gem uses four Windows system libraries (`avrt`, `dwmapi`, `imm32`, and `setupapi`) that they don't expect; v0.5.0 is the first release that accepts them. Until v0.5.0 existed, the pin was a trunk commit with that fix.

### Lota's gems

Lota isn't on RubyGems.org, so its gems come from `vendor/cache`, and `Gemfile.lock` records the SHA-256 checksum of each platform's gem. Fledge refuses a lockfile in which any checksum is empty. When you update Lota, write each platform's checksum into the `CHECKSUMS` section of `Gemfile.lock` by hand, as Fledge's README explains under "A gem that only `vendor/cache` holds".

### The icon

`script/make_icon.rb` draws the icon in code. It is released under CC0 (see `LICENSES/ICONS.md`).

### What goes into the app

Everything in the repository is copied into the app's `app/` folder, except `.git`, `.bundle`, `vendor/cache`, and `dist/`. That includes `test/` and the Markdown files, which are harmless there.

## Building on your own computer

You need Ruby 4.0.9, the version in `.ruby-version`. Each platform can build only its own app, so build the macOS app on a Mac and the Windows app on Windows.

```console
$ bundle install
$ bundle exec fledge build
dist/Dot Popper-arm64-darwin.tar.gz
dist/Dot Popper-arm64-darwin.dmg
```

The first build downloads Fledge's Ruby runtime for your platform, which takes about a minute. The `dist/` folder is ignored by git.

On Windows, the same two commands, run with Ruby 4.0.9 from RubyInstaller, write the `.zip` and the `-setup.exe`. Fledge's runtime includes NSIS and rcedit, the tools that make the installer and set the program's icon, so you don't need to install anything else.

### Checking a build without opening a window

CI's runners have no graphics card, so CI can't start the game. Instead, the launcher has a check mode. When the environment variable `DOT_POPPER_SMOKE` names a file, the launcher loads Lota, then the game's `conf.rb` and `main.rb`, and calls `Lota.conf`. Loading those files requires every file they depend on, so a file that didn't make it into the app fails at this step. The launcher writes what it found to the named file and exits with status 0, or with status 1 if anything is missing. It never opens a window or starts the engine.

To run the check on a macOS build with an empty environment, so that no Ruby on your computer can help it along:

```console
$ env -i HOME="$HOME" PATH=/usr/bin:/bin DOT_POPPER_SMOKE=/tmp/smoke.txt \
    "dist/Dot Popper-arm64-darwin/Dot Popper.app/Contents/MacOS/Dot Popper"; cat /tmp/smoke.txt
```

On Windows, `script/smoke-windows.ps1 -Dist dist -Results smoke` runs the same check twice with no Ruby on `PATH`: first on the unpacked `.zip`, then on a silently installed copy, which it uninstalls afterwards.

## What CI checks

The [Package workflow](.github/workflows/package.yml) runs on every push to `trunk`, on every tag that starts with `v0.`, and when started by hand from GitHub's Actions page. It has four jobs:

- **Test**, on Ubuntu, runs `bundle exec rake test`.
- **Windows x64**, on `windows-latest`, runs `bundle exec fledge build`, then `script/smoke-windows.ps1`, and uploads the `dot-popper-windows-x64` artifact. The artifact is uploaded even when the check fails, so there is always a build to inspect, but only a build from a green run is known to work.
- **macOS arm64**, on `macos-15`, runs `bundle exec fledge build`, runs the check on the `.app` with an empty environment, and uploads the `dot-popper-macos-arm64` artifact.
- **Release** runs only for a `v0.` tag. It attaches the builds to a GitHub prerelease for the tag. It requires the Windows job to have passed; the macOS build is included if it built. Nothing is published to RubyGems.

## What has been verified, and what hasn't

These have been verified on CI's runners and on the maintainer's Mac:

- `fledge build` writes the Windows `.zip` and `-setup.exe` on `windows-latest`, and the macOS `.app`, `.tar.gz`, and `.dmg` on Apple silicon.
- With no Ruby on `PATH`, the packaged program starts, loads Lota and its native library, loads the game's `conf.rb` and `main.rb` and everything they require, and exits cleanly. On Windows this holds both for the unpacked `.zip` and after a silent install. The installer also makes a Start menu shortcut and uninstalls cleanly.
- A Windows build of v0.4.0 made with `lota fuse` (see the last section) ran a 45-second autoplay session on one of Lota's CI runners. The runner had no graphics card, so it drew with Mesa's software OpenGL (llvmpipe). The bot went from the title screen through a full round, with pops, particles, and the clock, and the game quit on its own with status 0 and no errors. The icon showed in the title bar and the taskbar, and the game saved into `%APPDATA%\dot_popper`.

These have not been verified:

- **Playing on a real Windows PC.** Nobody has yet played the game on Windows with a real graphics card and driver, with real sound output, or with touch. The physics heap at the end of a round hasn't been seen on real Windows hardware either.
- **Restarting.** `lota run` restarts a game that calls `Lota::Event.restart`, but the fused launcher doesn't, because Lota's restart support is internal to `lota run`. In the packaged app, a restart quits instead.
- **Signing.** The builds are unsigned, so SmartScreen and Gatekeeper warn about them, and the `.dmg` isn't notarized.
- **A computer with no usable graphics driver.** Fledge's own testing found that Lota then shows an error message box that begins with a Ruby backtrace, which a player would find confusing.
- **License notices.** The notices for Lota's bundled libraries, in the app's `notices/` folder, haven't been reviewed.

## When `lota fuse` is released

Lota is adding a `lota fuse` command that wraps Fledge, and it hasn't been released yet. A Windows build of Dot Popper v0.4.0 made with it, on Lota's CI, is in the maintainer's `~/Downloads/dot-popper-windows-x64/`, with a `README.txt` giving its checksums and test results.

Once `lota fuse` is released, it should replace three things here: the launcher `bin/dot_popper`, the `programs:` entry in `fledge.yml`, and the Fledge pin in the `Gemfile`. The workflow would then run `bundle exec lota fuse` instead of `bundle exec fledge build`.
