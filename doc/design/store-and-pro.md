<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# The store and Pro

How Dot Popper sells Pro and decides who has it: Free and Pro, the build's channel, the store port and its adapters, receipts, license keys, free games, the offer, and what happens if setdef is gone. For anyone working on purchases, the store hosts and helpers, or the release checks. The reasons are in [ADR-0008](../adr/0008-native-features-live-outside-the-ruby-process.md), [ADR-0009](../adr/0009-the-store-is-a-port.md), [ADR-0010](../adr/0010-pro-comes-only-from-proof.md), [ADR-0011](../adr/0011-pro-outlives-setdef.md) and [ADR-0012](../adr/0012-free-games-20-then-3-a-day.md). Store accounts, signing and submission are in [doc/publishing.md](../publishing.md).

## Free and Pro

Pro is one purchase, the non-consumable product `com.setdef.dotpopper.pro`, all lowercase because Google Play takes no capitals in a product id, and the same in every store (`Store::PRODUCT_ID`, `Receipt::PRODUCT_ID`, and `ios/store_check/Tests/DotPopper.storekit`). It adds four things, as the offer lists them (`Style::WORDS.offer[:includes]`):

| Pro adds | Free has |
| --- | --- |
| Unlimited games | 20 games for good, then 3 a day (see [Free games](#free-games)) |
| Achievements | Achievements are earned and kept, and shown earned or open the same as for Pro. An achievement's dialog says how to earn it; the day earned, the progress and the count are Pro's, and a Free player's dialog has Get Pro. |
| Themes | The ordinary theme. Other themes are shown, and a theme is told when it arrives; using one opens the offer. |
| Friend groups | Join and Create open the offer. Leaving a group and deleting friend group data never need Pro. |

Pro never changes how the game plays or scores. Join, Create, Achievements and Themes look the same to Free and Pro: no "(Pro)" label and no locked look (Nielsen, consistency; Norman, a locked look is clutter). Clearing Stats never needs Pro. How achievements and themes look is in [progress.md](progress.md) and [look-and-sound.md](look-and-sound.md).

### `Entitlement#pro?`

Every Pro feature asks `Entitlement#pro?` (`lib/dot_popper/entitlement.rb`) and nothing else. It is true from exactly three sources:

1. **A receipt that verified during this run** (`Entitlement#prove`), handed over by the store. Nothing is saved: the next launch asks the store again. A receipt already refused is not checked again, since the store's answer is read four times a second.
2. **A license key that verifies** against the pinned keys (`Continuity::License#pro?`), on a website copy.
3. **`DOT_POPPER_PRO=1` in a test build** (`Entitlement.forced?`). `DOT_POPPER_PRO=0` is a Free player. A store build never reads it (`Build.settings`).

`Entitlement::DESKTOP_PRO` is false: a computer's copy is not Pro without a purchase. Setting it true would ship a desktop copy whole.

Nothing the game writes grants Pro: no file, flag or count. Within a run nothing is taken back, so a refund takes effect at the next launch, when the store stops handing over the receipt. A store copy is Free for the moment before the store's first answer at launch; free games are only counted when a game starts, so that costs nothing.

## The build's channel

What a build trusts and sells is decided by the build alone, never by anything a player can set at run time (the maintainer's rule: a kitchen-table workaround such as setting a variable must not grant Pro).

- `DotPopper::Build::CHANNEL` (`lib/dot_popper/build.rb`) is the channel the build is sold through, or nil for a test build. `Store::BUILD_CHANNEL` is the same constant. `Store.test_build?` is `BUILD_CHANNEL.nil?`. A build with a channel is a store build in the code's words (`Build.store?`), the `website` channel's included.
- The channels' names are listed once, in `Build`: `app-store`, `mac-app-store`, `google-play` and `microsoft-store` (`Build::STORES`, the app stores), and `website` (`Build::WEBSITE`), together `Build::CHANNEL_NAMES`. `Store::MAC_APP_STORE`, `MICROSOFT_STORE` and `WEBSITE` are the same strings, and the scripts take the list from `Build`.
- The repository's own file keeps it nil, so every playtest kit and every test build CI makes is a test build. A channel's own CI job sets it before `lota fuse` with `ruby script/set_build_channel.rb CHANNEL`, which rewrites the `CHANNEL = nil` line and refuses a name not in `Build::CHANNEL_NAMES`. The Package workflow's `website` jobs run it with `website`, its `msix` job with `microsoft-store`, and its `mac-app-store` job with `mac-app-store`. No workflow builds `app-store` or `google-play` yet. On a phone any channel other than `website` gives the native port.
- **License keys:** `Build.license_keys?` is false for the four app stores' channels, whose copies never accept, keep, verify or send a website license key (Apple 3.1.1; Google's billing rules): `Continuity::License.kept_in` keeps nothing in place of `license.txt` (the composition root opens the file only where it allows), so a key left on disk grants nothing and is never sent. The website channel and a test build keep `license.txt`.

### Developer settings in a store build

The game reads the environment only through `Build.settings(env, channel:)`, which `Composition::DeveloperSettings` wraps, and so do `conf.rb` (`DOT_POPPER_SAVE_AS`) and `main.rb` (`DOT_POPPER_SCENARIO`). In a test build it is the environment untouched. In a store build it drops every `DOT_POPPER_*` setting not in `Build::HARMLESS`:

`AUTOPLAY CALM DIAGNOSTIC_COLORS FAKE_DRAG FAKE_GAMEPAD FAKE_TILT FULLSCREEN NO_SHADERS NO_SPLASH NO_TUTORIAL NO_VULKAN PERF QUIT_AFTER RENDERERS SEED SHOTS TUTORIAL WINDOW`

So a new setting is inert in a store build until someone adds it to that list. Among those a store build ignores: `DOT_POPPER_AUTOMATED`, `PRO`, `SERVER`, `FREE_GAMES`, `TODAY`, `THEME_UNLOCKS`, `THEME`, `FAKE_SETDEF`, `FAKE_STORE_FAILS`, `SCENARIO`, `SAVE_AS` and `GROUP_SCREEN`.

In a store build, also:

- the pins are setdef's (`Continuity.pins_for`), and the receipts trusted are the stores' (`Receipt.trusted`); the composition root asks both of Monetization by the channel and hands them to the `Entitlement`;
- free games are always metered (`FreeGames.player?` is true, so the bot and scenarios do not skip the limit);
- an automated run still sells through the build's channel and uses the real pins, so a pipeline that wants fakes runs the test build.

Tests: `test/build_test.rb`, `test/composition/root_test.rb`, `test/set_build_channel_test.rb`, `test/check_build_test.rb`.

### Which store each build gets

`Store.for(platform, native:, fake:, entitlement:, website:, channel:)` (`lib/dot_popper/store.rb`) chooses once, called only from the composition root (`Composition::Root`). `platform` is the game's `Platform`, which the shell makes from `Lota::System.os` (`Shell::Platforms`); the table names each system as Lota does.

| Channel | iOS | Android | macOS (`OS X`) | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| nil (test build) | `FakeStore` | `FakeStore` | `WebsiteStore` + `FakeCheckout` | `WebsiteStore` + `FakeCheckout` | `WebsiteStore` + `FakeCheckout` |
| `website` (`Store::WEBSITE`) | `NativeStore` | `WebsiteStore` + `BrowserCheckout` | `WebsiteStore` + `BrowserCheckout` | `WebsiteStore` + `BrowserCheckout` | `WebsiteStore` + `BrowserCheckout` |
| `mac-app-store` (`MAC_APP_STORE`) | `NativeStore` | `NativeStore` | `Shell::StoreHelper` | `NoStore` | `NoStore` |
| `microsoft-store` (`MICROSOFT_STORE`) | `NativeStore` | `NativeStore` | `NoStore` | `Shell::StoreHelper` | `NoStore` |
| any other | `NativeStore` | `NativeStore` | `Store::CHANNELS[name]`, or `NoStore` | same | same |

`FakeStore`, `NativeStore` and `StoreHelper` sit behind a `Store`; `WebsiteStore` and `NoStore` answer the Store's methods themselves (`DotPopper::_Store` in `sig/dot_popper/store.rbs`). A platform in the phone host (`Platform#phone_host?`: iOS, Android) catches the store URL; `HELPER_CHANNELS` are the computer stores' channels, each sold through the native port only on the platform whose own store it is (`Platform#own_store`). An iOS build never takes the website store (`Platform#website_sales?`; Apple 3.1.1). `Store::CHANNELS` is the registry for other computer channels (such as Steam), each a callable taking `entitlement:`; it is empty. `NoStore` offers nothing, so no one is offered a purchase that cannot complete. No environment variable selects any of this.

`script/check_build.rb` and the release checks are in [Release checks](#release-checks).

## The store port

`Store` (`lib/dot_popper/store.rb`, Monetization's, in the core, which Steep checks strictly) is the game's half of every store purchase: the offer, Buy, Restore, the thanks, and proving Pro. Its only way to a store is a port: `open(url)`, answering whether the request was taken, and `read`, `remove` and `path` for the answer.

**The request.** A URL in the scheme `dotpopper-store` (`Store::SCHEME`): `dotpopper-store://ACTION?n=NUMBER&product=com.setdef.dotpopper.pro&file=PATH`, where ACTION is `open`, `buy` or `restore`, NUMBER counts up with each request, and PATH is where to answer (`-` for a store helper's standard output). The scheme is registered with no system, so no other app can send one.

**The answer.** The whole state each time, as `name=value` lines, so a missed answer costs nothing:

| Line | Means |
| --- | --- |
| `answer=7` | the number of the request it answers |
| `owned=1` | whether the store says the player owns Pro; it grants nothing |
| `state=ready` | `loading`, `working`, `ready`, `pending`, `canceled`, `restored`, `none`, `failed` or `unavailable` |
| `price=$1.99` | the store's own price, in the player's currency |
| `receipt=…` | while owned, the store's receipt (see [Receipts](#receipts)) |

`Store::STATES` maps those to what the offer tells apart; any other state is `:failed`. A receipt is proved from any answer. The price and state are taken only from an answer to the newest request (`answer >= number`), so an older answer never overwrites a newer state.

**When it is asked and read.**

- `#connect` asks `open` at launch (`Composition::Root#start`) and each time the offer opens, so a purchase on another device or after a reinstall simply appears and an unanswered request is cleared. It removes any old answer first, and asks nothing once the player has Pro.
- `#buy` asks only once a price has come and nothing is under way. The offer's Buy without a price is "Try again", which connects again (`UseCases::BuyPro#buy`).
- `#restore` asks unless something is under way.
- `#update` reads the answer every `Store::EVERY` (0.25 s). `UseCases::BuyPro#update`, which the offer of Pro (`Screens::Offer#update`) calls each frame through the `Show`, calls it only while no game is in play, so a purchase never lands mid-game (`test_a_store_is_not_read_during_a_game`).

**When Pro arrives.** `Entitlement` announces `Entitlement::ProGranted` to its listeners the moment Pro first arrives in a run: `by: :receipt` when a store's receipt verifies (`#prove`), `by: :license_key` when a key is entered (`#enter`, which the website store enters keys through). Pro the game starts with, from a key already entered or `DOT_POPPER_PRO`, is not an arrival. `UseCases::BuyPro` hears it first and reports the achievements already earned to the player's friend groups, whichever way Pro came; the offer of Pro (`Screens::Offer#call`) hears it next and, for a store's purchase while it is open, plays a tick (a key entered has its own tick as it is pressed). The composition root subscribes both, in that order.

### The adapters

**`NativeStore`** (`store.rb`) is the phones' adapter: its URLs go out by `Shell::UrlOpener` and its answers come back in `Shell::StoreAnswers`, the file `store_answer.txt` in the save folder. `StoreAnswers` is a plain file, not a `SaveFile`, because it is read four times a second and is usually absent. The hosts catch the URL before it leaves the app:

- iOS: `DotPopperApplication` in `ios/host/Host/main.m` hands it to `DotPopperStore` in `ios/host/Host/Store.swift` (StoreKit 2, which is Swift-only). It writes the answer file atomically.
- Android: `MainActivity#startActivity` hands it to `ProStore` (`android/host/src/main/java/org/setdef/fledge/host/ProStore.java`, Play Billing 9.1.0, which `android/host/build.gradle` adds). It writes a finished file and renames it over the answer. Each purchase is acknowledged, or Play refunds it after three days. A pending purchase never counts as owned.

Both ask for owned purchases first (StoreKit's `Transaction.currentEntitlements`, Play's `queryPurchasesAsync`), before the price, so a launch with no internet still finds Pro from the store's own cache. Only Restore calls `AppStore.sync`, which can ask the player to sign in.

**`Shell::StoreHelper`** (`lib/dot_popper/shell/store_helper.rb`) is the native port on a computer sold through its own store. The game cannot call StoreKit or Windows.Services.Store, so each build ships a small program, its store helper:

- Mac App Store: `macos/store/main.swift` (StoreKit 2), shipped at `Dot Popper.app/Contents/Helpers/dot-popper-store`, with an embedded Info.plist naming `com.setdef.DotPopper`. It runs as an accessory app so the purchase sheet can show, and gives up on any request after 15 minutes.
- Microsoft Store: `windows/store/dot_popper_store.c`, plain C against the WinRT ABI (CI and the build machines have MinGW and no C++/WinRT), shipped beside `Dot Popper.exe` as `dot-popper-store.exe`. A process the packaged game starts has the package's identity, which `StoreContext` needs.

`StoreHelper` starts the helper once for each request with the same URL and `file=-` (`StoreHelper::PIPE`), and reads the same whole-state answers from its standard output, each ending with an empty line, on a thread of its own. Two helpers can run at once; the newest request's answer is kept. `StoreHelper.find` looks for the helper, and for it in a `Helpers` folder, from the game's folder and up to six folders above it (`DEPTH`). With no helper, or in an automated run (`Automation`), `open` answers false and the request is refused. Both helpers take `--check`, which asks the store nothing; the Windows helper's `--self-test` runs in CI and in `test/windows_store_helper_test.rb`. Signing and packaging are in [doc/publishing.md](../publishing.md).

**`FakeStore`** (`lib/dot_popper/fake_store.rb`) is a test build's store on a phone, behind the same port. It answers `loading` or `working` at once and the real answer `FakeStore::READS` (2) reads later, so a purchase takes the same asynchronous road. Its price is `$1.99` (`FakeStore::PRICE`). Its ledger, `fake_store.txt`, is the store's own record of what this install bought, apart from `Entitlement`: Buy writes a receipt there (`Receipt.issue`, Play's form signed by `Receipt::TestKey`), and every answer while owned hands that receipt over, so the game proves a fake purchase with the code that proves a real one. A ledger edited to say anything else does not verify. A receipt bought before the product id was lowercased (`com.setdef.DotPopper.pro`, `FakeStore::EARLIER`) is bought again under today's id when the ledger is read, so a playtester keeps pretend Pro. Nothing on any screen says the store is a fake.

`DOT_POPPER_FAKE_STORE_FAILS` (`FakeStore::FAILS_BY`) makes the fake go wrong, for a developer only and in a test build only: `refused` (the system will not take the request), `unavailable` (no store answers), and `failed`, `canceled` or `pending` (how a Buy can end; a Restore takes `failed` and `canceled`, and `pending` is a Buy's alone).

**`WebsiteStore`** (`lib/dot_popper/website_store.rb`, with its checkouts) is the store for copies no store controls: setdef's website, itch.io, Homebrew, winget, a Linux package or an APK. It answers the Store's methods, plus `#keys?` (true: a license key is how Pro arrives) and `#paste`. Its price is `WebsiteStore::PRICE` (`$1.99`), which must match the checkout page. It has no Restore: the key is the purchase, on any device. Its checkout is a port, `#buy` answering the state to show:

- `BrowserCheckout` opens `BrowserCheckout::URL` (`https://dot-popper.setdef.com/buy`) in the player's browser and answers `:browser` ("Finish in your browser. Your key comes by email."), or `:unavailable`. The URL is the one constant to set once a payment company is chosen.
- `FakeCheckout`, a test build's on a computer, puts a real license key signed by the test key on the clipboard and answers `:copied` ("Your license key is copied. Paste it here."). Paste license key then takes the road a bought key takes.

**`NoStore`** offers nothing: `offered?` is false, its status is `:unavailable`, and every request does nothing.

### The store contract

`test/store_contract.rb` is one suite of what any adapter must do, included by each adapter's test, which writes `new_store(fails:)` and `relaunched(store)`. It reads answers only through `read`, as `Store` does. It checks that a request is taken and names where its answer goes; that an answer comes later than the question; that every answer is the whole state and names its request; the price on opening; buying after the price, and failing without it; that owning hands over a receipt the test build trusts; restoring nothing and restoring a purchase; a purchase known after a relaunch; removing the answer; each failure; and buying, restoring and failing again through `Store`.

- `FakeStoreContractTest` (`test/store_contract_test.rb`) runs it on `FakeStore`.
- `NativeStoreContractTest` runs it on `NativeStore` over a real answer file and a Ruby stand-in for the host, transcribed from `Store.swift` and `ProStore.java`. It shows `NativeStore`'s Ruby half and the suite's fairness, not the hosts.
- `StoreHelperContractTest` (`test/shell/store_helper_test.rb`) runs it on `StoreHelper` with real processes against a Ruby stand-in for the helper.

`ios/store_check` (XcodeGen, then `xcodebuild test` on a Simulator) drives the real `Store.swift` through its URLs and answer file against StoreKit's local test session; it is run by hand, not in CI. Other tests: `test/presentation/store_test.rb`, `test/presentation/website_store_test.rb`, and the GUI scenario `test/gui/scenarios/purchase.rb`.

## Receipts

A receipt is a store's signed record of a purchase of Pro, which the game verifies itself, offline, at each launch (`DotPopper::Receipt`, `lib/dot_popper/receipt.rb` and `lib/dot_popper/receipt/`). The host passes it as text after the store's name. Anything that goes wrong is a receipt that does not verify, never an error. OpenSSL and JSON load on first use.

| Form | Store | What `Receipt.valid?` checks |
| --- | --- | --- |
| `apple:<JWS>` | App Store, Mac App Store | `Receipt::Apple`: an ES256 JWS whose `x5c` chain runs from a leaf marked `1.2.840.113635.100.6.11.1`, through an intermediate marked `1.2.840.113635.100.6.2.1`, to Apple Root CA - G3 (`Receipt::APPLE_ROOT_G3`, SHA-256 `63343ABF…653E9179`), judged at the transaction's own `signedDate`; the signature by the leaf; then the bundle ID `com.setdef.DotPopper`, the product, and no `revocationDate`. These are the checks of Apple's App Store Server Library less its online ones. There is no `deviceVerification` check, since it needs a device identifier. |
| `play:<JSON>:<signature>` | Google Play | `Receipt::Play`: the RSA signature (PKCS #1 v1.5, SHA-1) of the purchase's original JSON by a key in `PLAY_KEYS`, then the package name, the product, and `purchaseState` 0 (4 is pending; *inference* from Play Billing's `getPurchaseState`). Both parts are standard Base64. |
| `microsoft:<token>:<SKU>` | Microsoft Store | `Receipt::Microsoft`: the in-app offer token is the product ID and the SKU is a Store ID (`/\A[0-9A-Z]{12}\/[0-9A-Z]{4}\z/`). It is Windows' word, not a signature: Windows.Services.Store gives an app no receipt for an add-on, so the helper reads the license Windows holds (`GetAppLicenseAsync`) at each launch. |

### Whose receipts a build trusts

A `Receipt::Trust` holds the Apple roots, the Play keys, the app's ID, the product ID, and whether Windows' word is taken (`windows_license`). `Receipt.trusted(channel)` picks one by the channel alone, and the composition root hands it to the `Entitlement`:

| Build | Trust | Accepts |
| --- | --- | --- |
| test build | `Receipt::TEST` | only Play-form receipts signed by `Receipt::TestKey` |
| `microsoft-store` | `Receipt::MICROSOFT_STORE` | only Windows' word, which reaches this build only down the helper's pipe, never from a file |
| any other store build | `Receipt::STORES` | Apple's root, and the Play keys once pinned |

`Receipt::TestKey` is a throwaway RSA key whose private half ships on purpose, as `Continuity::TestKeys` do. A test receipt proves nothing in a store build, and an edited `store_answer.txt` or ledger proves nothing anywhere (both tested). On Windows, replacing `dot-popper-store.exe` in the package's read-only install folder would grant Pro; that is changing the app's code, which the maintainer accepts as inevitable.

`Receipt::PLAY_KEYS` is empty until the maintainer copies the app's licensing key from the Play Console (Monetize, Monetization setup). Until then no Google Play purchase proves Pro, and `script/check_build.rb` fails a `google-play` build.

Tests: `test/receipt_test.rb` (including chains made in the test for `Receipt::Apple`), `test/entitlement_test.rb`.

## The offer

The offer of Pro is calm: nothing pushes it, no badge, timer, count or prompt after a game, because pressure of that kind crowds out the reasons to play (Nguyen; Ferrara on rewards bolted onto the surface; Rigby and Ryan's *Glued to Games*). It never appears during a game. No word on it says trial or demo (Apple 2.2; `test_no_word_of_the_offer_calls_it_a_trial_or_a_demo`). Its words are `Style::WORDS.offer`.

**Where it opens.** Over the screen the player was on, and Back closes it to that screen as it was. While it is open nothing under it takes a press.

- A Free player taps Get Pro in an achievement's dialog, a theme, Join or Create, or the new-theme card's Get Pro (`Show#open_offer_for`, focus `:achievements`, `:themes` or `:groups`).
- Home's Play with no game left, which then says Get Pro (`Screens::Offer#open_for_play`, focus `:games`).
- Game Over's main button with no game left, which says Get Pro (`Screens::Offer#open_for_play`).

**What it shows** (`OfferScreen` in `lib/dot_popper/presentation/offer_plan.rb`): under the heading "Dot Popper Pro", a note when it opened for want of a game ("No games left today."), the thing tapped (every theme but the ordinary one; the achievement's sign in the grid's dashed ring, its name and how to earn it, with no progress line, since progress is what Pro adds; or the feature's sign), its name, the rest of what Pro adds, a status line that keeps its place even when empty, then Buy and a second button. A short window held sideways puts the buttons on the right. Once the player has Pro only the thanks ("Thank you. It's yours.") and Back remain.

- **Buy** says "Buy for $1.99" with the store's own price (Google's policy requires it match), or "Try again" before a price has come. It is there while Pro is sold.
- **Restore Purchases** is always the second button on a store's copy (Apple 3.1.1).
- **Paste license key** is the second button on a website copy instead, and a store's copy never shows it or a checkout.

The status line says how the store is getting on: "Asking the store…", "One moment…", "Waiting for approval.", "That didn't go through.", "Nothing to restore on this account.", "The store isn't answering.", and the website store's own lines (see [License keys](#license-keys)). With no store the offer still opens from a feature and says the store isn't answering.

**Keys and buttons.** Enter, Space and a controller's Start press the screen's main button (`Show#primary`), which on the offer is Back, so no one buys by reflex. Buy (or Try again) has a control for each input that can complete a purchase alone: a tap or click on its button, a controller's Y (the button says "(Y)" while a controller is in use; `Screens::Offer#pad`, `Show#buy_label`), and Ctrl+B or Cmd+B on a keyboard (`Screens::Offer::KEY_BINDINGS`, `Screens::Offer#buy`; while the keyboard is the last input used the button says "(Ctrl+B)", or "(⌘B)" on a Mac, `Show#keyboard_used`); none is a press that means continue or back elsewhere. Escape and B are Back too. On a controller X is Restore Purchases, or Paste license key on a website copy (`Screens::Offer#pad`).

GUI galleries: `test/gui/scenarios/offer_gallery.rb`, `website_gallery.rb`.

## Free games

`FreeGames` (`lib/dot_popper/free_games.rb`, Lota-free) counts the games a Free player may still start.

- A fresh install holds `FreeGames::FIRST_GAMES` (20) games that never refill, and `FreeGames::DAILY` (3) for each local day, which do not carry over. A game spends the day's first, so the first games last. Both numbers are provisional; README.md and doc/publishing.md state them too.
- Nothing earns more: not ratings, reviews, sharing, nor the daily goal (Apple 3.2.2(x)). Nothing calls Free a trial or a demo.
- Pro counts nothing and keeps what was left (`#metered?` is false once `Entitlement#pro?`).
- The save is `games.txt`, lines `day=2026-11-08`, `spent=2` and `first_games_used=3`. It counts the first games used, not those left, so a change to `FreeGames::FIRST_GAMES` reaches every player. A save from an earlier build has `bank=17` (the first games left) instead; it is read as `FIRST_GAMES` less those, and written the new way at the next game. It is not part of `StatsBackup`, so clearing Stats cannot refill it. A missing file has all its first games. The day is the player's local date, from the same `today` as the daily goal (`DOT_POPPER_TODAY` in a test build).

**Where it meters.** `FreeGames.metered?` decides, and the composition root builds `FreeGames` with its answer: where Pro can be bought (the store is `offered?`), and someone is playing (`FreeGames.player?`). `FreeGames.player?` is always true in a store build; in a test build it is false for the autoplay bot and for a GUI scenario, unless the scenario sets `DOT_POPPER_FREE_GAMES`. A build with `NoStore` counts nothing, since a limit with no way past it is a dead end. Test builds have a store, a fake one, so they are metered like the final game, desktop included. `DOT_POPPER_FREE_GAMES=n` (`FreeGames.starting`) starts a new save with n first games and n a day.

**The one way into a game.** `UseCases::StartGame` (`lib/dot_popper/use_cases/start_game.rb`) is the only way into a game: Play, and the opening of the Tutorial (a first Play and How to play alike), whose game begins as it opens, go through it. It spends a game and starts it, or with none left starts nothing, and the `Show` opens the offer. `Cabinet` starts a game only when asked, never on a press, and only through its `Cabinet::Starts`, which it hands out once: the composition root gives them to `StartGame`, and asking again raises (`test/use_cases/start_game_test.rb`, `test/composition/root_test.rb`). The cabinet has no method of its own that starts a game, so nothing that holds only the cabinet can, even by sending a name (`test/cabinet_test.rb`). As a second line, the same test fails if any other line in the game's code takes a cabinet's Starts or reads `StartGame`'s by reflection (`@starts`); it reads the source, so a name built at run time would pass it. Ruby cannot forbid reflection, so this guards against an honest mistake, not a determined one. `test/presentation/games_test.rb` gives a `Show` a door that never opens and checks that no way in starts a game. The Tutorial's end and its Skip start nothing, so they spend nothing.

**What the player sees.** Home's Play has the count in its own label ("23 games left", `Words#games_left`), and with none left says Get Pro over "No games left today. 3 more tomorrow." (`Words#no_games_left`). Game Over's Play again does the same. The books: Schell (the player should always know what they have and what comes), Norman (visible state), Johnson (plain words, one name for one thing).

Tests: `test/free_games_test.rb`, `test/presentation/games_test.rb`; gallery `test/gui/scenarios/games_gallery.rb`.

## License keys

A website copy's Pro is a license key, sent by email, which "Paste license key" enters.

**The format** (`Continuity::LicenseKey`, `lib/dot_popper/continuity/license_key.rb`, agreed with the server): version 1 is 81 bytes, the version, a random 16-byte id, and an Ed25519 signature by a license-signing key over the label `dot-popper/license-key/v1` and those first 17 bytes. As text it is `DP-` and 130 letters of Crockford base32 in groups of five. Reading it ignores case, spaces, line breaks and hyphens, reads O as 0 and I or L as 1, and takes it with or without `DP-`. The game verifies it offline against the license-signing keys its pins trust.

**Entering one.** Paste license key enters the clipboard's text (`WebsiteStore#paste`, through `Entitlement#enter` into `Continuity::License`); on a computer, Ctrl+V or Cmd+V does the same on the offer (`Screens::Offer::KEY_BINDINGS`, `Screens::Offer#paste`). A key can also be typed on a computer's keyboard there (`WebsiteStore#type`, `UseCases::BuyPro#type`): letters, digits and hyphens add to it, alone or with Alt, but not with Ctrl or Cmd, which a player holds for a shortcut (select all, copy, quit), not a character (*Universal Principles of Design*, mental models; [input.md](input.md), "Keyboard"), Backspace takes one away, Enter enters it, and Space does nothing while one is being typed, since a key ignores spaces (`Screens::Offer#typing?`). The status line shows "Key:" and the last 24 characters. Letters typed there do not trigger H, M or C. Nothing typed is stored unless it is a valid key, and nothing is shown to anyone else. The answers: "That isn't a license key.", "Copy your license key first.", "That key is already here.", or Pro at once.

**One key, one device at a time** (`Continuity::License`, `license.txt`, as agreed with the server). The file holds `key: DP-…`, `secret: <hex>`, `next: <hex>` while a check waits, and `registered: yes` once the server has answered the entry.

- Entering a key saves it with a fresh 32-byte secret; it is Pro at once. The next check sends `POST /licenses` with the key, the secret and a nonce, and the server keeps only the secret's SHA-256, so the key moves to this device.
- After that, each start sends `POST /license_checks` with the key's id, the secret, a fresh `next` and a nonce. `next` is saved before it is sent, so a retry is the same request. A signed "current" makes `next` the secret.
- Answers are signed by the server's certified online key over `dot-popper/license-check/v1`, the nonce, the key id and the verdict (`Continuity::SignedAnswers`).
- Only a signed "moved" removes the key and Pro. No answer, a refusal, a bad signature or no internet never does. There is no counter to edit and no device identifier.
- A key entered while setdef is gone is Pro at once and registers when setdef answers.

Ed25519 comes from OpenSSL in every build, with no pure-Ruby fallback (`Continuity::Ed25519`). `Ed25519.available?` checks the server's published test vector. With `DOT_POPPER_PERF=1` the game prints whether it verifies, and the Package workflow's Windows, macOS and Linux playthroughs and the Android emulator check (`.github/android_emulator_checks.sh`) fail unless it does.

### Pins

`Continuity::Pins` (`lib/dot_popper/continuity/pins.rb`) holds a build's 32-byte Ed25519 public keys: the proof roots that certify the server's online key, and the license-signing keys, each a main one and a sealed backup. Nothing a server sends can add to them.

- `SETDEF_PINS` are setdef's own: two proof roots (ids `8336ad85d326749b` and `ad88ca8070d052b7`) and two license-signing keys. `PINNED = SETDEF_PINS`, which a store build trusts.
- `TEST_PINS` are throwaway keys whose private seeds ship in `Continuity::TestKeys`, for the fakes, in the test build's own part (`lib/dot_popper/test_build/test_keys.rb`, loaded only when `Build::PARTS` names `test_build`). A test build trusts them, and nothing they sign verifies against `PINNED` (tested). A build for sale carries neither: `script/set_build_channel.rb` stamps its `Build::PARTS` empty, and its package leaves the folder out (`script/channel_contents.rb`).
- `Continuity.pins_for(channel)` is `PINNED`; the test build's part prepends its own answer, `TEST_PINS` for no channel.
- `Continuity.live?` is true when the pins are setdef's: only then may a build ask the real server.

## When setdef is gone

**The one test** (`Continuity::Watch`, `Continuity::Gone`, `setdef.txt`, `lib/dot_popper/continuity/watch.rb`): setdef is gone when its server gives no valid signed answer to `GET /proof` and at least one connectivity check answers as expected. The checks (`Continuity::Connectivity::CHECKS`) are Apple's, Google's and Microsoft's, asked only after the proof fails, one at a time, stopping at the first that answers: `http://captive.apple.com/hotspot-detect.html` (200, "Success"), `http://connectivitycheck.gstatic.com/generate_204` (204, empty) and `http://www.msftconnecttest.com/connecttest.txt` (200, "Microsoft Connect Test"). With no internet nothing changes. A device found gone stays gone, and `setdef.txt` keeps the day it was first found gone, until setdef's server proves itself again. A runtime that cannot verify Ed25519 never finds setdef gone.

The watch runs once each start (`Composition::Root#start`) and again when a key is entered, on a thread at priority -2, and its result is taken up on the game's thread (`Watch#update`, each frame). `Continuity::Gone` announces each answer it takes up to its listeners: `SetdefHere` when setdef's server proved itself, which makes `ServerChoice` forget a chosen server, and `SetdefGone` (with the day it was first found gone and today) whenever a check leaves setdef gone, which makes `Themes` open themes by their dates once it has been gone long enough. At launch, before any check, the composition root (`Composition::Root`) opens them by date once. While setdef answers it also sends what the license owes.

| Build | Watch |
| --- | --- |
| test build | `Continuity::FakeSetdef`, in this process, signing with the test keys and sending nothing; `DOT_POPPER_FAKE_SETDEF=here\|gone\|offline\|moved` sets how it behaves, for a developer; its ledger is `fake_setdef.txt` |
| store build, live pins, not automated | `Continuity::SetdefServer` on `Network::Server::SERVER_URL`, and the real connectivity checks |
| otherwise | `Continuity::NoWatch`: setdef is never gone and a key never moves |

The proof and the license requests always go to setdef's own server, never to a replacement chosen with Change Server.

**What changes while setdef is gone:**

- **Themes open by date.** Each theme has its day in `Theme::ALL` (`Theme#opens_on`) (Ghost and Jack-o'-lantern 2026-10-01, Pumpkin pie and Turkey 2026-11-01, Ornament, Santa, Snowman, Peppermint and Gingerbread 2026-12-01, Awake and Eclipse 2027-10-01). Once setdef has been gone `Themes::GONE_DAYS` (180) days, every theme whose date has passed opens for everyone, as if the server had released it (`Themes#open_by_date`), checked at each start and after each check. Using one still needs Pro.
- **Change Server** (`ServerChoice`, `server.txt`, and the screen `Screens::ChangeServer`) is a pill on Settings, shown only while setdef is gone, that opens a screen of its own. The warning comes first, since it is what to know before choosing (Podmajersky; Hodent): "The server you choose receives your friend group scores. It can't give you Pro." Then what to do, which server is in use, and Paste server address and Use setdef's server. Only one HTTPS address with a host and nothing else is taken (`ServerChoice.https?`), from the clipboard (Ctrl+V or Cmd+V too). It is used from the next start, since a group belongs to one server, for friend groups and themes. Its token is kept in `group-<host>.txt`, so setdef's token is never sent elsewhere. When setdef answers again the pill goes and the game returns to setdef's server (`ServerChoice#forget`). Nothing a server sends grants Pro. Apple's 2.5.19 bars hidden features, so Change Server is to be described in Notes for Review.
- **On a website copy, Pro is no longer sold** (`WebsiteStore#sold?`): Buy goes, the offer says "Pro is no longer sold.", and Paste license key stays, so a key bought earlier still enters (Johnson: say plainly what has happened; no dead button).

Tests: `test/continuity/license_test.rb`, `test/continuity/signatures_test.rb`, `test/composition/root_test.rb`.

## Release checks

A build for sale is checked as it was built, not as the repository says: the repository's own `build.rb` is always a test build.

- `ruby script/check_build.rb CHANNEL VERSION FOLDER` loads the game's code from the unpacked app in FOLDER (its `game/dot_popper`, as `lota fuse` lays it out), with Lota installed, and fails unless all of it is the app's own; `Build::CHANNEL` is CHANNEL; `Continuity.pins_for(CHANNEL)` are `SETDEF_PINS` and share no key with `TEST_PINS`; no license key signed by any of `Continuity::TestKeys` verifies, no proof certificate by the test root verifies, and the fake store's receipt proves nothing in it, each beside its control (the same proof does verify against the test build's trust, so a Ruby that verifies nothing fails); no setting grants Pro or changes the server; and the app's `fledge.yml` says VERSION. A `google-play` build also needs `Receipt::PLAY_KEYS`; a `website` build needs no Play key or store identifier. It reaches nothing on the internet.
- The Package workflow runs it on every build for sale it makes: each file of each `website` build (the `.zip` and the installer on Windows, the `.tar.gz` and the `.dmg` on macOS, the `.tar.gz` and the AppImage on Linux), the MSIX's folder and the Mac App Store app. The packaged Ruby's Ed25519 is checked by each playthrough instead (`DOT_POPPER_PERF=1`; see [License keys](#license-keys)).
- `ruby script/check_store_identifiers.rb CHANNEL` fails while an identifier CHANNEL needs is unset in the environment, still a placeholder (`setdef.DotPopper`, `CN=Dot Popper test`), or the wrong form: `MSIX_IDENTITY_NAME` and `MSIX_PUBLISHER` for `microsoft-store`, `APPLE_TEAM_ID` for `mac-app-store` and `app-store`, none for `website` or `google-play`. No workflow releases a store's build yet, so none runs it; the store's release job will, with the repository variables.
- `ruby script/release_kind.rb TAG` says what a tag releases: `website`, `playtest` or `none` (its `WEBSITE_TAGS`). A `website` release carries the website builds alone; the test builds and the kits, whose fakes give Pro away, go only to a `playtest` prerelease. How to release is in [doc/publishing.md](../publishing.md).

Tests: `test/check_build_test.rb` (an app laid out as `lota fuse` lays it out), `test/release_kind_test.rb`, `test/store_identifiers_test.rb`, `test/set_build_channel_test.rb`, `test/build_test.rb`.

## Unverified

None of these can be checked without the maintainer's store accounts or a real device purchase:

- A real App Store, Mac App Store, Google Play or Microsoft Store purchase, sandbox or otherwise, through the hosts and helpers.
- A real StoreKit JWS through `Receipt::Apple`, and real Play data through `Receipt::Play`.
- That StoreKit's `currentEntitlements`, Play's `queryPurchasesAsync` and Windows' license list answer offline from their caches.
- That Fledge's iOS OpenSSL does X.509 and ECDSA (*inference*: it is the OpenSSL that does Ed25519).
- That StoreKit takes the Mac helper as the app, and that the purchase sheet shows for it; that the Microsoft Store's dialog shows over the game's window.
- That Partner Center accepts dots in a product ID.
- A payment company and its checkout; the real server's `/licenses` and `/license_checks` against this client; the real connectivity checks from a device; Paste on iOS and Android clipboards.
