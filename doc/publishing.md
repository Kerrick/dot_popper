# Publishing Dot Popper

What each store needs, what Dot Popper already has, and what is still missing. Store rules change; check each one's current policy before submitting. Everything here was written on 2026-11-05.

## Decide first: the license

Dot Popper is all rights reserved from after v0.9.9 on; `LICENSE` says so, and its Credits screen too. Lota, which ships inside every build, stays AGPL-3.0-or-later, and the App Store's and Mac App Store's terms add restrictions that the GPL family forbids, but setdef owns Lota, Fledge and Dot Popper, so the game ships Lota under setdef's own rights, not under the AGPL. Say so wherever a store page or document describes Lota's license. The third-party code inside Lota still binds the game: every build must carry `NOTICES.txt` and Fledge's `notices/` unmodified in substance, OpenAL Soft must stay a separately replaceable library with its source in `sources/`, and `bundle licenses` should be checked before each release. Before a store build, confirm it, and that built apps no longer carry Fledge 0.6.0's AGPL notices (Lota 0.3.0 fixes that).

The bundled third-party code also needs a check before any store build:

- **OpenAL Soft is LGPL-2.1.** It ships on Android (as a shared `libopenal.so`, which a user can replace) and in the desktop builds, so their notices must include its source offer. iOS doesn't use it: there, Lota links Apple's own OpenAL framework, as LÖVE does, so the iOS build contains no LGPL code.
- **FreeType** is used under the FreeType License (not the GPL), which needs a credit line in the app.
- **The rest is permissive:** LÖVE (zlib), SDL (zlib), Ruby (Ruby or BSD-2), Box2D (MIT), Fredoka and Iosevka (SIL OFL 1.1). Dot Popper's own sounds and icon are setdef's, all rights reserved.

Every store build should carry a "Licenses" or "About" screen, or file, listing these.

## What every store needs from Kerrick

- **A privacy policy URL** (the server side writes the policy; this is what it must match). Facts:
  - Every build, store builds included, uses `https://server.dot-popper.setdef.com` (`Groups::Settings::SERVER_URL`). Saves, stats and `games.csv` stay on the device.
  - Nothing is sent until a Pro player creates or joins a friend group. Then the game sends an anonymous token it asks the server for, the group's join code, and the score of each counting game. The player types no name or text and gives no account or email. Leave, and Delete my data (which removes the player's scores), are in the app.
  - A themes check (`GET /themes?started_on=`, no token) sends the date the player first played. It is being added to the game, so check it is in the build you submit.
  - The server's proxy and logs see IP addresses, and its rate-limit entries hold them up to a day.
  - Nothing is used for tracking, advertising or analytics, and nothing is shared with other parties as far as the game's code goes; what the server does with the data beyond the above is the server's policy to state.
- **Data safety and privacy-label answers.** The categories below are a reading of the facts above, for the maintainer to enter or change; Apple's category pages could not be fetched, so the key spellings come from memory of Apple's documentation (Xcode and App Store Connect validate them).
  - **Apple (App Privacy), also declared in `ios/host/Host/PrivacyInfo.xcprivacy`:** "Yes, we collect data." Tracking: no. Data types, each for **App Functionality** only:
    - *Gameplay Content*: scores in friend groups (also covers the join code and which group and seat the player holds). **Linked to the user**, because the server stores the scores under the player's token.
    - *User ID*: the anonymous token. **Linked** (it is the identifier the scores are linked by).
    - *Other Usage Data*: the first-play date in the themes check. **Not linked** (no token is sent).
    - IP addresses: not declared. Apple's list has no IP category, and the game does not store them; the server's logs and rate-limit entries do (up to a day). If the maintainer or Apple's review reads "Device ID" as covering them, add it, linked and for App Functionality.
  - **Google Play (Data safety):** collects data: yes. Shares data with other parties: no (the server is setdef's own). Encrypted in transit: yes (HTTPS). Users can request deletion: yes, in the app (Delete my data), and the policy should say so.
    - *App activity > Other actions*: scores in friend groups (collected, not shared; **optional**, because only players who use groups send it; purpose App functionality).
    - *Personal info > User IDs*: the anonymous token (optional, App functionality).
    - *App activity > App interactions*: the first-play date in the themes check (not optional, because the check is automatic; purpose App functionality).
    - *Device or other IDs*: no. IP addresses: the server's logs hold them, so the maintainer decides whether to list them under *Device or other IDs*; the game itself reads none.
    - Re-read each category's current definition when entering.
- **Free games and Pro, to disclose in the listing and the notes for review.** A Free copy starts with a one-time stock of 20 games (never refilled) and 3 games a local day (not carried over); a game counts when started, and the tutorial and How to play cost none. One non-consumable purchase, Pro (`com.setdef.DotPopper.pro`), restorable from its page, makes games unlimited and adds Achievements, Themes and Friend groups. Say all of that, with the numbers, in the description and in Apple's Notes for Review (guidelines 2.1(b) and 2.3.1(a)), and attach the sandbox purchase to the build so a reviewer can see the unlock. Never call it a trial or a demo (2.2); keep the price out of the name, subtitle and keywords (2.3.7). Games are never earned through ratings, reviews, sharing or the daily goal (3.2.2(x)). Play's listing and Data safety form say the same, and its price must match Play Billing's. The numbers are `FreeGames::BANK` and `FreeGames::DAILY`; change the listing with them.
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

Set a variable with `gh variable set NAME --repo setdef/dot_popper`, and a secret with `gh secret set NAME --repo setdef/dot_popper`. Apple's signing will add certificates and an App Store Connect API key here, all as secrets, once that work is done. The Microsoft Store signs an MSIX itself, so it needs no key.

## Google Play

- **Account:** a Google Play Console developer account, a one-time fee. New personal accounts must run a closed test with a minimum number of testers for a minimum number of days before production; check the current numbers.
- **Build status:** the Android build is experimental, made by the phone route Lota 0.3.0 documents, and it is a debug APK. Landscape runs at about 15 fps on the Nord.
- **What's missing:**
  - **An upload key.** The Android workflow already builds the App Bundle Play requires (`.aab`, the artifact `dot-popper-play-bundle`) and signs it once the key is in the repository's secrets. Play App Signing holds the app's own key. To make the upload key, keep the keystore somewhere safe and off GitHub, then add the secrets:

    ```sh
    keytool -genkeypair -v -keystore dot-popper-upload.jks -alias upload \
      -keyalg RSA -keysize 2048 -validity 10000
    gh secret set ANDROID_UPLOAD_KEYSTORE --repo setdef/dot_popper < <(base64 -i dot-popper-upload.jks)
    gh secret set ANDROID_UPLOAD_KEY_ALIAS --repo setdef/dot_popper --body upload
    gh secret set ANDROID_UPLOAD_KEY_PASSWORD --repo setdef/dot_popper
    ```

    Use one password for the keystore and the key.
  - A fix for the landscape lag. It blocks release: a portrait-only lock is not an acceptable workaround.
  - Ideally a Lota release that supports Android, so the build doesn't depend on an experiment branch.
- **Already right:** arm64-v8a, targetSdk 36, Back handled, no permissions requested.

## Apple App Store (iPhone and iPad)

- **Account:** the Apple Developer Program, a yearly fee. The free Personal Team can't publish.
- **Build status:** the Xcode project from the iOS kit builds, signs, installs, and plays on a real iPad Pro and iPhone 13 mini, from Lota 0.3.0's experimental iOS route and host.
- **What's missing:**
  - Signing with an Apple Distribution certificate and an App Store provisioning profile.
  - An App Store Connect record for `com.setdef.DotPopper`, then an upload through Xcode's Organizer or `xcrun altool`/Transporter, then TestFlight.
  - A privacy manifest (`PrivacyInfo.xcprivacy`) declaring no tracking and any required-reason APIs the runtime uses, such as file timestamps.
  - App icons at every required size.
  - The license decision above.
  - A Release build rather than Debug.

## Mac App Store

- **Account:** the same Apple Developer Program.
- **Build status:** `lota fuse` makes a working, unsigned `.app` for arm64.
- **What's missing:**
  - **The App Sandbox** (entitlement `com.apple.security.app-sandbox`). Dot Popper writes only to its own Application Support folder, which a sandboxed app gets inside its container, and reads the clipboard only to write to it. Tested on 2026-11-06: v0.8.6's app, signed locally with only that entitlement, started, played a game, quit cleanly, and saved to `~/Library/Containers/com.setdef.DotPopper/Data/Library/Application Support/`, so Lota and Fledge's runtime need nothing more for the sandbox. Copy my result and sound weren't checked under it; the clipboard needs no entitlement, and audio output doesn't either.
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
2. Copy **Package/Identity/Name** (like `12345setdef.DotPopper`) into the repository variable `MSIX_IDENTITY_NAME`, and **Package/Identity/Publisher** (like `CN=XXXXXXXX-...`) into `MSIX_PUBLISHER` (Settings, Secrets and variables, Actions, Variables). Until then the build uses the placeholders `setdef.DotPopper` and `CN=Dot Popper test`.
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

## Where things stand (2026-11-06)

For whoever picks this up next.

- **In progress:** moving every build to Lota 0.2.2 and Fledge v0.6.0 (desktop, Lota's own Android and iOS routes), and renaming the app identifier to `com.setdef.DotPopper`. When Package, Kits (with iOS), Android and GUI are all green on trunk, tag **v0.9.0**, the release candidate (no hyphenated versions: they make RubyGems treat a version as a prerelease), and install it on every device. The first run of Lota's own Android host on a real phone will be the OnePlus Nord's; send any error verbatim to Lota's maintainer, and record any workaround here.
- **Phones' `NOTICES.txt`, written by Lota.** `android.yml` and the iOS job of `kits.yml` run `rake android:notices` and `rake ios:notices` in the clone of Lota the workflow builds from (Lota since 0.3.0). The file sits at the project's top (`NOTICES.txt` beside `game/` and Fledge's `notices/`), two folders above the game, where `Shell::NoticeFiles` already looks (a test covers that layout). The workflows check it: Android unzips `assets/fledge.zip` from the APK, Kits looks in the built `.app` for each configuration.
  - **OpenAL Soft source offer (Android only): the exact source is bundled in the app.** `rake android:notices` copies the `openal-soft-1.24.3.tar.bz2` that `rake android:deps` built `libopenal.so` from into the project's `sources/` folder, after checking its SHA-256, and the notices name it, its URL and its SHA-256, and carry the LGPL text. That is a source offer met by the app itself with no separate written offer or release asset. iOS uses Apple's OpenAL, so its notices name no LGPL code.
  - The libraries are Lota's record of what its link takes, which Lota says it did not read file by file for the phones; if Lota's phone record changes, the notices follow the `LOTA_REF` the workflow builds.
- **iOS privacy manifest, added** as `ios/host/Host/PrivacyInfo.xcprivacy`; the Kits workflow checks that the Debug and Release apps carry it. Lota's audit of what the iOS app links (LÖVE, SDL 3.4.10, the prebuilt libraries, Lota's iOS host, Fledge's runtime) against Apple's required-reason APIs found only FileTimestamp and SystemBootTime, the two Fledge's template declares. **Still to do:** confirm the reasons when App Store Connect validates the first upload; its e-mail lists anything missing. The manifest declares: `NSPrivacyTracking` false; no tracking domains; no collected data types; accessed APIs: FileTimestamp (C617.1), SystemBootTime (35F9.1). DiskSpace (E174.1) and UserDefaults (CA92.1) are not declared, since nothing uses them; SDL's read of the mouse's scroll-direction preference goes through CFPreferences, which is not on Apple's list. Add DDA9.1 if the game ever shows file dates, and 3B52.1 if the app ever declares document types or a file picker.
- **Mac App Store:** the sandbox test above signed without the hardened runtime. If a store-signed build with the hardened runtime fails to start, it may need `com.apple.security.cs.allow-jit` for Ruby's YJIT, or YJIT turned off.
- **Waiting on the maintainer:** developer accounts (Apple, Google Play, Microsoft Partner Center), the Android upload key, the store listings and their license text, and a privacy policy page.
- **Not wanted for now:** Homebrew.
