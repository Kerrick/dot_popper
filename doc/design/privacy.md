<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Privacy facts

How the game's privacy facts are declared, generated and enforced: every file it saves, every request it makes, what is shipped and asked of the system, and the iOS privacy manifest. For anyone who adds a save file, a request, a library or a permission. The facts themselves are [doc/privacy.json](../privacy.json); why they come from the code is [ADR-0014](../adr/0014-privacy-facts-come-from-the-code.md).

## One source, generated

The declarations live in `lib/dot_popper/privacy/`, and each request's with the part of the game that makes it. `Privacy::Document` (`lib/dot_popper/privacy/document.rb`) turns them into `doc/privacy.json`:

```
bundle exec rake privacy
```

`test_the_document_is_current` (`test/privacy/declared_test.rb`) fails while the committed file differs from what the code generates, so its words are never older than the code. The public privacy policy and the store forms are written from it. On every `v*` tag, the Package workflow's `privacy-document` job runs `script/publish_privacy_document.sh`, which regenerates the file, fails if that changed it or if its `game_version` is not the tag's, and sends it to the server.

The document has: what stays on the device (`on_device`), every request (`network`), purchases, the libraries shipped (`sdks`), permissions and the privacy manifest's settings, the sensor, sharing, deletion, the answers for Apple's and Google's forms (`store_labels`), and `declared_but_not_enforced`.

## A declaration is the only way in

### Save files

`Privacy::SAVE_FILES` (`lib/dot_popper/privacy/save_files.rb`) lists every file in the save folder as a `KeptFile`: its name (or a dated name's shape, with a `pattern`), what it holds, who makes it, and either a `label` a player reads or an `Aside` saying why they needn't (`:test_only`, `:developer_only` or `:diagnostics`, with a reason). `sent` names what in it also leaves the device, as the request field it goes in, and `sent_when` says when.

`Shell::SaveFile` refuses a name that is not declared: `SaveFile.new` calls `Privacy::SaveFiles.declare!`, which raises `ArgumentError`, dated names included. So no file exists that the document does not list. `store_answer.txt` is written by the phones' hosts and read by `Shell::StoreAnswers`, which is not a `SaveFile`; it is declared all the same.

### Requests

Each part of the game that makes requests declares its own, as `REQUESTS`, where it lives. Each is a `Network::Request`: its kind, verb and path, its `query` and `body` fields (each a `Network::Field` with what it is, in a player's words, and the store label it counts under), whether it sends the player's token, when it happens, its feature, and `to`, the host when it is not the game's server (the connectivity checks).

| Part | Declares |
| --- | --- |
| `Groups::REQUESTS` (`lib/dot_popper/groups/requests.rb`) | `POST /player`, `GET /groups`, `POST /groups`, `POST /memberships`, `GET /groups/:id`, `GET /groups/:id/history`, `POST /achievements`, `DELETE /groups/:id/membership`, `DELETE /player` and `POST /games`, for friend groups ([friend-groups.md](friend-groups.md)) |
| `ThemeReleases::REQUESTS` (`lib/dot_popper/theme_releases.rb`) | `GET /themes` with `started_on`, for every player, with no token ([look-and-sound.md](look-and-sound.md)) |
| `Continuity::SetdefServer::REQUESTS` (`lib/dot_popper/continuity/setdef_server.rb`) | `GET /proof`, `POST /licenses` and `POST /license_checks`, for setdef being there and license keys ([store-and-pro.md](store-and-pro.md)) |
| `Continuity::Connectivity::REQUESTS` (the same file) | the three connectivity checks, to `captive.apple.com`, `connectivitycheck.gstatic.com` and `www.msftconnecttest.com` |

`Privacy::REQUESTS` (`lib/dot_popper/privacy/requests.rb`) merges them in the order of `Privacy::PARTS`, which is the document's, and refuses a kind declared twice.

`Network::Job.of` is the only way to make a request: it takes the verb and path from a declaration, fills in the path's id and the query, and raises unless the body's and the query's fields are exactly the declared ones; `Job.new` is private, and `Network::Link` takes a job, never a verb and a path. Friend groups' `Session::Job.of` makes each of its jobs by it, and `ThemeReleases`, `Continuity::SetdefServer` and `Continuity::Connectivity` make theirs by it, each from its own declarations.

`Privacy::UNBUILT_REQUESTS` holds the declarations of requests not yet built, which the wire test then leaves out and the document marks `in_this_build: false`; once a request is built, its declaration moves to its part. It is empty. `test_unbuilt_requests_are_only_those_not_yet_in_the_code` fails as soon as an unbuilt request's query fields appear in the game's code, so a request cannot ship without being played in the wire test.

## The tests

**The wire test.** `test/privacy/requests_test.rb` plays every built request through a real `Session` and a real `Network::Link` against a local server on `127.0.0.1`, plus the themes check, the proof, a key's entry and check, and the three connectivity checks pointed at that server. It compares what arrived with each declaration (method, path, fields, token), fails for a declared request never sent, and fails for anything sent that nothing declares. It also checks that the saved token and unsent score really leave the device, that a job can only be made from a declaration, and that every part declaring requests is in `Privacy::PARTS`, with no request declared anywhere else.

**Source scans.** Comments are stripped first (Prism).

- No network primitive (`Net::`, sockets, `OpenSSL`, `open-uri`, HTTP gems) appears outside `network/link.rb`, except `automation.rb`, which only refuses connections, and the signature checks in `continuity/ed25519.rb` and `receipt/`, which may use OpenSSL's keys and certificates and nothing that connects. The native hosts use no `URLSession`, `NSURLConnection`, `HttpURLConnection`, OkHttp or Volley.
- No file write, delete or rename appears outside `shell/save_file.rb`, except `StoreAnswers`' `File.delete` and the screenshot capture in `shell/app.rb`.
- Every `SaveFile.new` name in the code is declared and every declared fixed name is in the code; exactly three names are computed, and those match their patterns.
- Only `accelerometer.rb` reads `Lota::Sensor`, and only `url_opener.rb` calls `open_url`, whose own schemes are `dotpopper-share` and `dotpopper-store`.

**Exact lists.** Each of these must equal what it describes, or `bundle exec rake` fails:

| Declaration | Compared with |
| --- | --- |
| `Privacy::SHIPPED_GEMS` | `Gemfile.lock`'s default group (Fledge leaves out development and test) |
| `Privacy::ANDROID_DEPENDENCIES` | `android/host/build.gradle`'s dependencies. Billing is pinned to its exact version, `com.android.billingclient:billing:9.1.0`, so a bump makes someone re-read its manifest. |
| `Privacy::ANDROID_PERMISSIONS` | `android/host/src/main/AndroidManifest.xml`'s permissions: INTERNET and VIBRATE |
| `Privacy::IOS_USAGE_STRINGS` | `NS*UsageDescription` keys in `ios/host/Host/Info.plist`: none |
| `Privacy::STORE_LABELS`, `APPLE_PURPOSE`, `APPLE_TRACKING`, `APPLE_TRACKING_DOMAINS`, `APPLE_APIS` | `ios/host/Host/PrivacyInfo.xcprivacy` |

Every label must be used by some request, and the labels with an Apple type must equal the manifest's data types. INTERNET's stated purpose must name exactly the features this build reaches the server for (`Privacy.features_built`). `ANDROID_MERGED` records what Play Billing's own manifest adds (`com.android.vending.BILLING`), read by hand.

Also tested: what each file says it sends is really sent; the "stays on your device" sentence names every exception; no request but a license key's concerns a purchase; the deletion words are the screens' own.

## Written for players

Each file carries a `label` or an `Aside` with its reason. Each library and limit is a `Privacy::Item` with either `plain` words for a player or a `record_only` reason it is not for them, never both (`Item` raises otherwise). `test_what_a_player_reads_is_short_and_plain` checks every sentence a player reads (`Document#player_words`): none over 25 words, and none with developer terms (renderer, Vulkan, Lota, LÖVE, SDL, Fledge, SDK, API, token, manifest, `.txt`, `.csv`, http). The books: Zinsser, Williams, and Pinker on the curse of knowledge. `test_what_the_privacy_page_shows_uses_the_glossarys_words` checks what the server's page shows of the document (the labels, what each file holds, when each request happens, and the deletion sentence) against `GLOSSARY.md`: a record, Stats, and the player's private code, the name a player reads for the identifier the server gives a player, where the code and the API say token. A request's kind is the code's name for it (`game` for `POST /games`); no page shows it.

The document says nothing of the server's own behavior, except the IP-address answers on the store forms (`Privacy::IP_ADDRESSES`), which the maintainer asked for: the server's proxy, request log and rate-limit notes see the address, the game neither reads nor sends it as data, and how long each is kept is the server's own policy to state.

## declared_but_not_enforced

`Privacy::NOT_ENFORCED` names plainly what no test here can check: what Apple, Google and Microsoft do with a purchase; how the iOS and Android hosts and the system's share sheet behave beyond their source; what Lota, LÖVE, SDL and Fledge's runtime do inside the app (audited by hand for required-reason APIs); permissions a library's manifest adds when Android merges it, and its transitive libraries; and whether the stores' label definitions still fit the answers.

## The iOS privacy manifest

`ios/host/Host/PrivacyInfo.xcprivacy` declares no tracking and no tracking domains. Its collected data types, each for App Functionality only, come from `Privacy::STORE_LABELS`:

| Label | Apple type | Linked | Sent |
| --- | --- | --- | --- |
| `gameplay_content` | `NSPrivacyCollectedDataTypeGameplayContent` | yes | the join code, the score of a game that counts, and the keys of achievements earned |
| `user_id` | `NSPrivacyCollectedDataTypeUserID` | yes | the anonymous token, with every request that sends one |
| `other_usage` | `NSPrivacyCollectedDataTypeOtherUsageData` | no | the themes check's first-play date and the proof's nonce, with no token |

Gameplay Content and User ID are linked because the server keeps scores under the token, and Apple counts data tied to an identifier as linked. Join and membership data fall under Gameplay Content; Apple has no closer category. The fourth label, `license_key`, has no Apple or Google type: only a website copy sends it, and no store's copy does, so no store form asks about it. Apple's list has no IP-address category, so IP addresses are not a data type; the document leaves the choice of Device ID to the maintainer. Google's answers (`store_labels.google`) are generated from the same labels.

**Required-reason APIs** (`Privacy::APPLE_APIS`): FileTimestamp (C617.1) and SystemBootTime (35F9.1). They are the two that an audit of what the iOS app links (LÖVE, SDL, the prebuilt libraries, Lota's iOS host and Fledge's runtime) found, and the two Fledge's template declares; Dot Popper's file replaces Fledge's whole, so it keeps both. The game's own code uses neither DiskSpace nor UserDefaults: it saves through `Lota::Filesystem`'s read, write, remove and `info`, never shows a file date, and asks for no free space or user defaults. SDL's read of `com.apple.swipescrolldirection` goes through CFPreferences, which is not on Apple's list. App Store Connect's validation has the last word. More on the iOS app is in [doc/ios.md](../ios.md) and [platforms.md](platforms.md).
