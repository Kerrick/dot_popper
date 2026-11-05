# Packaging Dot Popper

Dot Popper ships as an app that runs without Ruby. [Fledge](https://github.com/setdef/Fledge) builds it: it copies the game, its gems, and a Ruby built to be moved into one folder, then writes an archive and an installer.

| Platform | What you get |
| --- | --- |
| Windows x64 | `Dot Popper-x64-mingw-ucrt.zip`, which holds `Dot Popper.exe`, and `Dot Popper-x64-mingw-ucrt-setup.exe`, an installer that needs no administrator |
| macOS arm64 | `Dot Popper-arm64-darwin.dmg`, and `Dot Popper-arm64-darwin.tar.gz`, which holds `Dot Popper.app` |

## Getting the Windows build

**From a release.** When a `v0.*` tag is pushed, the [Package workflow](.github/workflows/package.yml) attaches both builds to a prerelease on the [Releases page](https://github.com/Kerrick/dot_popper/releases).

**From any push to `trunk`.** Open the [Package workflow's runs](https://github.com/Kerrick/dot_popper/actions/workflows/package.yml), pick a green run, and download the `dot-popper-windows-x64` artifact from the bottom of its page. You must be signed in to GitHub. The artifact is a `.zip` that holds the two files above. Artifacts expire after GitHub's retention period (90 days by default).

**Installing.** Run `Dot Popper-x64-mingw-ucrt-setup.exe`. It installs into `%LOCALAPPDATA%\Programs` and adds a Start menu shortcut. Or unpack `Dot Popper-x64-mingw-ucrt.zip` anywhere and run `Dot Popper.exe`. The build is unsigned, so SmartScreen warns the first time: choose **More info**, then **Run anyway**. To uninstall, use Settings > Apps, or run `uninstall.exe` in the installed folder.

To cut a release, set `version:` in `fledge.yml` to match, then push the tag:

```console
$ git tag v0.1.0 && git push origin v0.1.0
```

## How it is put together

- **`bin/dot_popper`** is the program Fledge ships. The game's own `main.rb` only defines Lota's callbacks, so the launcher starts the repository's folder as a *fused* Lota game, with `Lota::Boot.new(folder, ARGV, fused: true).call`. A fused game saves its files under its identity alone in the system's application-data folder, the way LÖVE's shipped games do. It is not in a `Lota` folder, as `lota run` puts it. `lota run` from the repository's root still works as before and never runs the launcher.
- **`fledge.yml`** lists the launcher under `programs`, so a bare `fledge build` builds it and not `main.rb`. It also gives the name, identifier (`com.kerricklong.DotPopper`), version, publisher, icon, and installers (`dmg`, `nsis`).
- **Fledge** is in the `Gemfile`'s `development` group, so it stays out of the app. It is pinned to trunk commit `007b5514e4630ca02a67aabb5b8b701e66c919cd` rather than the `v0.4.0` tag: v0.4.0 refuses Lota's Windows gem because the gem imports `avrt`, `dwmapi`, `imm32`, and `setupapi` from System32, and trunk accepts them. Move to the next Fledge tag once it includes that fix.
- **Lota's gems** come from `vendor/cache`, with all three platforms' checksums in `Gemfile.lock`. Fledge refuses a lockfile with an empty checksum. If you update Lota, write each platform's SHA-256 into `CHECKSUMS` by hand (Fledge's README, "A gem that only `vendor/cache` holds").
- **The icon** is drawn by `script/make_icon.rb` and is CC0 (`LICENSES/ICONS.md`).
- **Everything in the repository ships** inside the app's `app/` folder, except `.git`, `.bundle`, `vendor/cache`, and `dist/`. That includes `test/` and the Markdown files, which do no harm.

## Building locally

You need Ruby 4.0.9 (`.ruby-version`). Each platform builds only its own app, so build on a Mac for macOS and on Windows for Windows.

```console
$ bundle install
$ bundle exec fledge build
dist/Dot Popper-arm64-darwin.tar.gz
dist/Dot Popper-arm64-darwin.dmg
```

The first build downloads Fledge's Ruby runtime for your platform (about a minute). `dist/` is ignored by git.

On Windows, the same two commands write the `.zip` and the `-setup.exe`, with RubyInstaller's Ruby 4.0.9. Fledge's runtime brings NSIS and rcedit, so you install nothing else.

**Checking a build without a window.** If `DOT_POPPER_SMOKE` names a file, the launcher loads Lota, checks that `conf.rb` and `main.rb` shipped, writes what it found to that file, and exits with status 0, or 1 if anything is missing. It opens no window. CI uses this because its runners have no GPU:

```console
$ env -i HOME="$HOME" PATH=/usr/bin:/bin DOT_POPPER_SMOKE=/tmp/smoke.txt \
    "dist/Dot Popper-arm64-darwin/Dot Popper.app/Contents/MacOS/Dot Popper"; cat /tmp/smoke.txt
```

On Windows, `script/smoke-windows.ps1 -Dist dist -Results smoke` runs the same check on the unpacked `.zip` and on an installed copy, with no Ruby on `PATH`, and then uninstalls.

## What CI checks

The [Package workflow](.github/workflows/package.yml) runs on every push to `trunk`, on `v0.*` tags, and by hand (workflow_dispatch):

- **Test** (Ubuntu) runs `bundle exec rake test` once a `Rakefile` exists, and skips with a notice until then.
- **Windows x64** (`windows-latest`) runs `bundle exec fledge build`, then `script/smoke-windows.ps1`, and uploads `dot-popper-windows-x64`.
- **macOS arm64** (`macos-15`) runs `bundle exec fledge build`, smoke-runs the `.app` with an empty environment, and uploads `dot-popper-macos-arm64`.
- **Release**, on a `v0.*` tag, attaches the builds to a GitHub prerelease. It needs the Windows build to succeed. The macOS build is included when it built. Nothing is published to RubyGems.

## What is verified and what is not

Verified, on CI runners and on the maintainer's Mac:

- `fledge build` writes the Windows `.zip` and `-setup.exe` on `windows-latest`, and the macOS `.app`, `.tar.gz`, and `.dmg` on Apple silicon.
- With no Ruby on `PATH`, the built program starts, loads Lota 0.1.2 and its native library, finds the game's `conf.rb` and `main.rb`, and exits cleanly. On Windows this holds both unpacked and after a silent install, and the installer makes a Start menu shortcut and uninstalls.

Not verified:

- **The game actually playing on Windows.** CI runners have no GPU and no audio device, so the Windows check never opens a window or plays a sound. Fledge's own trial of a Lota 0.1.2 game on these runners did draw with Mesa's software OpenGL (llvmpipe) and played sound through OpenAL Soft's null backend. It did that with a test game that quits on its own, which Dot Popper has no mode for. The first real play test is on a Windows PC with a GPU.
- **Restarting.** `lota run` restarts a game that calls `Lota::Event.restart`. The fused launcher does not (Lota's restart support is internal to `lota run`), so in the packaged app a restart quits instead.
- **Signing.** Builds are unsigned, so SmartScreen and Gatekeeper warn. The `.dmg` is not notarized: on macOS, right-click the app and choose **Open** the first time.
- **When a computer has no usable graphics driver,** Lota shows a message box that begins with a Ruby backtrace (a finding from Fledge's trial).
- **License notices** for Lota's bundled libraries in the app's `notices/` were not reviewed.

## When `lota fuse` ships

Lota is adding a `lota fuse` command that wraps Fledge. Once it is released, it should replace `bin/dot_popper`, the `programs:` entry in `fledge.yml`, and the Fledge pin in the `Gemfile`. The workflow would then run `bundle exec lota fuse` in place of `bundle exec fledge build`.
