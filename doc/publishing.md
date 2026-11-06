# Publishing Dot Popper

What each store needs, what Dot Popper already has, and what is still missing. Store rules change; check each one's current policy before submitting. Everything here was written on 2026-11-05.

## Decide first: the license

Dot Popper is AGPL-3.0-or-later, and so is Lota, which ships inside every build. The App Store's and Mac App Store's terms add restrictions that the GPL family forbids, so an AGPL app on those stores is widely held to be a license conflict. Kerrick Long holds the copyright to both Dot Popper and Lota, so he can resolve it without anyone else: add an app-store exception to both licenses, or license the store builds differently.

The bundled third-party code also needs a check before any store build:

- **OpenAL Soft is LGPL-2.1.** On iOS it is linked statically, and the LGPL requires that users be able to relink. That means shipping the object files, or linking it dynamically. On Android it is a shared `libopenal.so`, which is fine.
- **FreeType** is used under the FreeType License (not the GPL), which needs a credit line in the app.
- **The rest is permissive:** LÖVE (zlib), SDL (zlib), Ruby (Ruby or BSD-2), Box2D (MIT), Fredoka (SIL OFL 1.1), and the CC0 sounds and icon.

Every store build should carry a "Licenses" or "About" screen, or file, listing these.

## What every store needs from Kerrick

- **A privacy policy URL.** Dot Popper collects nothing: it keeps its saves on the device and makes no network calls. A one-page policy saying so, hosted anywhere public, satisfies all five.
- **Store art:** screenshots at each store's sizes, a 1024×1024 icon (`script/make_icon.rb` can render one), a short description, and an age rating (everyone).
- **A real version number** for each submission, taken from the tag. The kits already do this.

## Google Play

- **Account:** a Google Play Console developer account, a one-time fee. New personal accounts must run a closed test with a minimum number of testers for a minimum number of days before production; check the current numbers.
- **Build status:** the Android build is experimental, made from Lota's unreleased commit `84c0eda`, and it is a debug APK. Landscape runs at about 15 fps on the Nord.
- **What's missing:**
  - A release build signed with an upload key Kerrick creates and keeps. Play App Signing holds the app key.
  - An Android App Bundle (`.aab`), which Play requires, rather than an APK. Whether `fledge build android` can make one needs asking.
  - Either a fix for the landscape lag, or a portrait-only lock (`screenOrientation` in the host manifest) for the first release.
  - Ideally a Lota release that supports Android, so the build doesn't depend on an experiment branch.
- **Already right:** arm64-v8a, targetSdk 36, Back handled, no permissions requested.

## Apple App Store (iPhone and iPad)

- **Account:** the Apple Developer Program, a yearly fee. The free Personal Team can't publish.
- **Build status:** the Xcode project from the iOS kit builds, signs, installs, and plays on a real iPad Pro and iPhone 13 mini, from Lota 0.1.3's experimental iOS path.
- **What's missing:**
  - Signing with an Apple Distribution certificate and an App Store provisioning profile.
  - An App Store Connect record for `com.kerricklong.DotPopper`, then an upload through Xcode's Organizer or `xcrun altool`/Transporter, then TestFlight.
  - A privacy manifest (`PrivacyInfo.xcprivacy`) declaring no tracking and any required-reason APIs the runtime uses, such as file timestamps.
  - App icons at every required size.
  - The license decision above, and the OpenAL Soft relinking question.
  - A Release build rather than Debug.

## Mac App Store

- **Account:** the same Apple Developer Program.
- **Build status:** `lota fuse` makes a working, unsigned `.app` for arm64.
- **What's missing:**
  - **The App Sandbox** (entitlement `com.apple.security.app-sandbox`). Dot Popper writes only to its own Application Support folder, which a sandboxed app gets inside its container, and reads the clipboard only to write to it. Lota and Fledge's runtime need testing under the sandbox.
  - Signing with "Apple Distribution" or "3rd Party Mac Developer" identities, and an installer package (`productbuild`) signed for the store.
  - An App Store Connect record; the same identifier can serve both stores.
  - The license decision above.
  - Possibly a universal (x86_64 plus arm64) build, which isn't possible today, since Lota and Fledge ship no Intel Mac build. An arm64-only Mac app is allowed.

## Microsoft Store (Windows)

- **Account:** a Microsoft Partner Center developer account, a one-time fee for individuals.
- **Build status:** `lota fuse` makes a working NSIS installer (`-setup.exe`) and a `.zip`, unsigned.
- **What's missing, by one of two routes:**
  - **An MSIX package,** which the Store signs itself, so no certificate is needed. This means packaging the fused folder as MSIX with an `AppxManifest.xml` (MakeAppx, or the MSIX Packaging Tool).
  - **The existing `.exe` installer, submitted as a Win32 app:** the Store then requires the installer, and the binaries, to be code-signed with a certificate from a trusted authority. It also needs a silent-install switch, which NSIS has (`/S`), and a versioned download URL, which GitHub releases provide.

  MSIX avoids buying a certificate. Either way, Fledge's runtime under MSIX's virtualized filesystem needs a test.

## Homebrew

- **No account needed.** Homebrew's own `homebrew/cask` has notability rules and expects signed, notarized apps, so start with a tap of your own: a public repository named `Kerrick/homebrew-tap`. Users would then run `brew install --cask kerrick/tap/dot-popper`.
- **The cask** points at the release's `Dot.Popper-arm64-darwin.dmg`, with its version and `sha256` checksum, and runs `app "Dot Popper.app"`.
- **Signing:** an unsigned app trips Gatekeeper after a brew install. Signing with a Developer ID certificate and notarizing (`xcrun notarytool`) removes that, and needs the Apple Developer Program.
- **Linux:** Homebrew on Linux could install the AppImage the same way, with a formula in the same tap.

## Suggested order

1. Decide the license question. Nothing on Apple's stores can ship without it.
2. **Homebrew tap:** no fees, an hour's work, and it can ship today, unsigned, with a Gatekeeper caveat.
3. **Microsoft Store via MSIX:** a one-time fee, no certificate.
4. **Apple Developer Program,** which unlocks the App Store, the Mac App Store, and notarized Homebrew at once.
5. **Google Play,** once Lota's Android route is released and the landscape lag is fixed or the app is locked to portrait.
