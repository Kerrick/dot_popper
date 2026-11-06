# Publishing Dot Popper

What each store needs, what Dot Popper already has, and what is still missing. Store rules change; check each one's current policy before submitting. Everything here was written on 2026-11-05.

## Decide first: the license

Dot Popper is AGPL-3.0-or-later, and so is Lota, which ships inside every build. The App Store's and Mac App Store's terms add restrictions that the GPL family forbids, so an AGPL app on those stores is widely held to be a license conflict. Kerrick Long holds the copyright to both Dot Popper and Lota, so he can resolve it without anyone else. His commercial licensing is handled on his own site, not in this repository or Lota's. Lota will never offer a switch that claims a different license or changes its license statement: `lota fuse` will write a notices file of facts, with Lota's AGPL-3.0-or-later statement always present. If a store build's notices must read differently under his authority, that is a step in Dot Popper's own build, settled with his licensing, not something Lota provides.

The bundled third-party code also needs a check before any store build:

- **OpenAL Soft is LGPL-2.1.** It ships on Android (as a shared `libopenal.so`, which a user can replace) and in the desktop builds, so their notices must include its source offer. iOS doesn't use it: there, Lota links Apple's own OpenAL framework, as LÖVE does, so the iOS build contains no LGPL code.
- **FreeType** is used under the FreeType License (not the GPL), which needs a credit line in the app.
- **The rest is permissive:** LÖVE (zlib), SDL (zlib), Ruby (Ruby or BSD-2), Box2D (MIT), Fredoka (SIL OFL 1.1), and the CC0 sounds and icon.

Every store build should carry a "Licenses" or "About" screen, or file, listing these.

## What every store needs from Kerrick

- **A privacy policy URL.** Dot Popper collects nothing: it keeps its saves on the device and makes no network calls. A one-page policy saying so, hosted anywhere public, satisfies all five.
- **Store art:** screenshots at each store's sizes, a 1024×1024 icon (`script/make_icon.rb` can render one), a short description, and an age rating (everyone).
- **A real version number** for each submission, taken from the tag. The kits already do this.

## Settings CI reads, and which are secret

CI takes each store's values from the repository's settings on GitHub, never from its files, so nothing here is committed. Until a value is set, CI builds with an obviously fake stand-in, or leaves the build unsigned, so it can still check the build.

| Name | Kind | What it is | Secret? |
| --- | --- | --- | --- |
| `MSIX_IDENTITY_NAME` | Variable | The package's identity name from Partner Center (Product identity). | No: every MSIX published to the Store carries it in its manifest. |
| `MSIX_PUBLISHER` | Variable | The publisher, `CN=` and an ID, from the same page. | No, for the same reason. |
| `ANDROID_UPLOAD_KEYSTORE` | Secret | The upload keystore, in base64. | Yes: whoever has it can upload builds as you. |
| `ANDROID_UPLOAD_KEY_ALIAS` | Secret | The key's alias in that keystore. | Kept with the keystore. |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Secret | The keystore's and key's password. | Yes. |

Set a variable with `gh variable set NAME --repo Kerrick/dot_popper`, and a secret with `gh secret set NAME --repo Kerrick/dot_popper`. Apple's signing will add certificates and an App Store Connect API key here, all as secrets, once that work is done. The Microsoft Store signs an MSIX itself, so it needs no key.

## Google Play

- **Account:** a Google Play Console developer account, a one-time fee. New personal accounts must run a closed test with a minimum number of testers for a minimum number of days before production; check the current numbers.
- **Build status:** the Android build is experimental, made by the phone route Lota 0.2.2 documents, and it is a debug APK. Landscape runs at about 15 fps on the Nord.
- **What's missing:**
  - **An upload key.** The Android workflow already builds the App Bundle Play requires (`.aab`, the artifact `dot-popper-play-bundle`) and signs it once the key is in the repository's secrets. Play App Signing holds the app's own key. To make the upload key, keep the keystore somewhere safe and off GitHub, then add the secrets:

    ```sh
    keytool -genkeypair -v -keystore dot-popper-upload.jks -alias upload \
      -keyalg RSA -keysize 2048 -validity 10000
    gh secret set ANDROID_UPLOAD_KEYSTORE --repo Kerrick/dot_popper < <(base64 -i dot-popper-upload.jks)
    gh secret set ANDROID_UPLOAD_KEY_ALIAS --repo Kerrick/dot_popper --body upload
    gh secret set ANDROID_UPLOAD_KEY_PASSWORD --repo Kerrick/dot_popper
    ```

    Use one password for the keystore and the key.
  - A fix for the landscape lag. It blocks release: a portrait-only lock is not an acceptable workaround.
  - Ideally a Lota release that supports Android, so the build doesn't depend on an experiment branch.
- **Already right:** arm64-v8a, targetSdk 36, Back handled, no permissions requested.

## Apple App Store (iPhone and iPad)

- **Account:** the Apple Developer Program, a yearly fee. The free Personal Team can't publish.
- **Build status:** the Xcode project from the iOS kit builds, signs, installs, and plays on a real iPad Pro and iPhone 13 mini, from Lota 0.2.2's experimental iOS route and host.
- **What's missing:**
  - Signing with an Apple Distribution certificate and an App Store provisioning profile.
  - An App Store Connect record for `com.kerricklong.DotPopper`, then an upload through Xcode's Organizer or `xcrun altool`/Transporter, then TestFlight.
  - A privacy manifest (`PrivacyInfo.xcprivacy`) declaring no tracking and any required-reason APIs the runtime uses, such as file timestamps.
  - App icons at every required size.
  - The license decision above.
  - A Release build rather than Debug.

## Mac App Store

- **Account:** the same Apple Developer Program.
- **Build status:** `lota fuse` makes a working, unsigned `.app` for arm64.
- **What's missing:**
  - **The App Sandbox** (entitlement `com.apple.security.app-sandbox`). Dot Popper writes only to its own Application Support folder, which a sandboxed app gets inside its container, and reads the clipboard only to write to it. Tested on 2026-11-06: v0.8.6's app, signed locally with only that entitlement, started, played a round, quit cleanly, and saved to `~/Library/Containers/com.kerricklong.DotPopper/Data/Library/Application Support/`, so Lota and Fledge's runtime need nothing more for the sandbox. Copy my result and sound weren't checked under it; the clipboard needs no entitlement, and audio output doesn't either.
  - Signing with "Apple Distribution" or "3rd Party Mac Developer" identities, and an installer package (`productbuild`) signed for the store.
  - An App Store Connect record; the same identifier can serve both stores.
  - The license decision above.
  - Possibly a universal (x86_64 plus arm64) build, which isn't possible today, since Lota and Fledge ship no Intel Mac build. An arm64-only Mac app is allowed.

## Microsoft Store (Windows)

- **Account:** a Microsoft Partner Center developer account, a one-time fee for individuals.
- **Build status:** `lota fuse` makes a working NSIS installer (`-setup.exe`) and a `.zip`, unsigned.
- **The route taken: MSIX.** The Package workflow's `msix` job wraps the fused Windows folder in an MSIX with an `AppxManifest.xml` (Windows.FullTrustApplication, `runFullTrust`). The Store signs MSIX itself, so no certificate is needed. CI checks it by signing a copy with a throwaway certificate, installing it, playing 90 seconds of autoplay, checking that its records were saved, and removing it. Under MSIX, Windows redirects the game's roaming AppData into the package, so its saves land in `%LOCALAPPDATA%\Packages\<package family name>\LocalCache\Roaming\dot_popper\` (confirmed by CI on 2026-11-06), and uninstalling the app removes them. The other route, the NSIS `-setup.exe` as a Win32 app, would need a purchased code-signing certificate.

Steps for the maintainer:
1. In Partner Center, reserve the name "Dot Popper" and open the product's **Product identity** page.
2. Copy **Package/Identity/Name** (like `12345Kerrick.DotPopper`) into the repository variable `MSIX_IDENTITY_NAME`, and **Package/Identity/Publisher** (like `CN=XXXXXXXX-...`) into `MSIX_PUBLISHER` (Settings, Secrets and variables, Actions, Variables). Until then the build uses the placeholders `KerrickLong.DotPopper` and `CN=Dot Popper test`.
3. Run the Package workflow (or push a `v0.*` tag). Download the unsigned `Dot-Popper-X.Y.Z.0.msix` from the run's `dot-popper-msix` artifact, or from the release's assets on a tag.
4. Upload it in the submission's **Packages** section. The Store signs it.

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
5. **Google Play,** once Lota's Android route is released and the landscape lag is fixed.
