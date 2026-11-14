<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# The screens

Every screen of Dot Popper and how it is laid out, as the code has it: the setdef splash, Home, Settings, Stats, Achievements, Game Over, the share preview, Credits, and the rules every screen shares (buttons, reaches, hover, headings, layout plans). It is for anyone changing what a player sees outside a game. The offer of Pro and buying it are in [store-and-pro.md](store-and-pro.md), the friend groups' screens in [friend-groups.md](friend-groups.md), the Themes screen and the new-theme card in [look-and-sound.md](look-and-sound.md), what Stats counts in [progress.md](progress.md), and the tutorial in [tutorial.md](tutorial.md).

Where the parts go is worked out without Lota in `lib/dot_popper/presentation/` (plans and screens, tested with `RoughMeasure`), and drawn by painters in `lib/dot_popper/shell/`. Sizes are graphics units; many scale by `Layout#ui`, which is the safe area's shorter side over 760, kept between 0.72 and 1.35.

## The screen map

| Screen | Opened from | Back goes to | Code |
| --- | --- | --- | --- |
| setdef splash | launch | (ends by itself, or on any press) | `Presentation::Splash`, `Shell::SplashPainter` |
| Home | after the splash; Back from every screen over it; Game Over's Home | (Escape twice quits on a computer; Android's Back leaves the app) | `HomeScreen`, `Shell::HomePainter` |
| Stats | Home's Stats button | Home | `StatsLayout`, `Shell::StatsPainter` |
| Achievements | Home's Achievements button; Game Over's new-achievement line | Home | `AchievementsScreen`, `Shell::AchievementsPainter` |
| an achievement's dialog | a cell of Achievements | Achievements | `AchievementDialog` |
| Themes | Home's Themes button | Home | [look-and-sound.md](look-and-sound.md) |
| Friend groups | Home's Friend groups button; Game Over's title line | Home | [friend-groups.md](friend-groups.md) |
| Settings | Home's Settings | Home | `SettingsScreen`, `Shell::SettingsPainter` |
| Credits and licenses | Settings | Settings | `CreditsLayout`, `Shell::CreditsPainter` |
| Privacy | Settings | Settings | `PrivacyScreen`, `Shell::PrivacyPainter` |
| Change Server | Settings, only while setdef is gone | Settings | `ServerScreen`; see [ADR-0011](../adr/0011-pro-outlives-setdef.md) |
| a game | Play, Play again | (none) | [rules.md](rules.md) |
| Game Over | the clock running out | Home | `GameOverScreen`, `Shell::GameOverPainter` |
| share preview | Game Over's Share my score, on a computer | Game Over | `ShareScreen`, `Shell::SharePreviewPainter` |
| the offer of Pro | a Free player's tap on a Pro feature; Play or Play again with no game left | the screen it opened over | [store-and-pro.md](store-and-pro.md) |

The screens over Home (`Screens::Page`) open over the one on top (`Show#open_page`), and Back closes the top one (`Show#close_page`): Settings opens Credits, Privacy and Change Server over itself, so Back returns to it; the rest go back to Home. `Show#stats?`, `#settings?` and the like ask whether that screen is the one on top (`Show#on_top?`). Every screen over Home is the presentation's alone: `Cabinet` stays on Home meanwhile, so no press there can start a game or touch a score. Each is drawn over Home's drifting dots, veiled at 90% (`Style::STATS.veil`, `GROUPS.veil`); Home itself veils them at 76% (`Style::HOME.dim`).

The experience goal behind the map (Fullerton): a player is popping dots within two seconds of launch, and can start another game with one press after Game Over. Every other feature is on its own screen, opened on purpose.

## Screens as objects

Each screen is an object in `Presentation::Screens` (`lib/dot_popper/presentation/screens/`; [ADR-0018](../adr/0018-screens-are-objects-on-a-stack.md)), named for the screen: `Home`, `NewTheme` (the card telling of a new theme), `Tutorial`, `Game`, `GameOver`, `SharePreview`, `Offer`, `Stats`, `Achievements`, `AchievementDialog`, `Themes`, `Settings`, `Credits`, `Privacy`, `ChangeServer` and `FriendGroups` (the friend groups' pages, which `GroupPanel` keeps). The classes named `HomeScreen`, `GameOverScreen`, `ShareScreen`, `OfferScreen` and the like are their layouts: values whose `#plan` places the parts (see "Layout plans").

**Which screen is on top.** `Screens.made_for` makes one of each screen in `Screens::ALL` as the `Show` is made, each given the collaborators its constructor asks for by name (the use cases, the clipboard, the presentation's own stores), and none is made again. Under everything is the screen for `Cabinet`'s state (`Show#state_screen`): `Home`, or `NewTheme` while a new theme waits to be told; the `Tutorial` over its paused game; a `Game`; or `GameOver`. A screen opened over another is pushed on the stack over it (`Show#layers`, `Show#open_layer`), and only the screen on top is ever closed (`Show#close_layer`), so Back returns to the screen under it as it was. `Show#screen` is the top of the stack, or with nothing open the screen for the state: the one place that says which screen is on top, and `Show#on_top?`, which `#stats?`, `#settings?` and the like ask, is that same question. As Home shows after a game, the stack is emptied.

| Opened over | Screens |
| --- | --- |
| Home | Stats, Achievements, Themes, Settings, Friend groups, the offer of Pro |
| Settings | Credits, Privacy, Change Server |
| Achievements | an achievement's dialog, the offer (from its Get Pro) |
| Themes, the new-theme card, Friend groups | the offer of Pro, leading with what was tapped |
| Game Over | the share preview, the offer (from Play again with no game left) |

**What each answers** (`Screens::Screen`, whose answers are a screen's when it has none of its own):

| Method | Answers | Asked by |
| --- | --- | --- |
| `controls` | its buttons (`Control`), where drawn and where a press reaches them | `Show#controls`, so taps and hover |
| `answers` | the kinds of control (`Control.kind`) it answers: a press of any other reaches nothing | `Screen#press`; `inputs_test.rb` |
| `tap`, `press`, `pressed`, `empty` | what a tap does: the button under it (`pressed`), or empty space (`empty`; a gamepad's A there is `primary`); a list's rows wait for their release (`list_row?`) | `Show#tap`, `Show#press` |
| `primary`, `back` | the main button (Enter, Space, A at nothing), and Back, Close or Home (Escape, B), saying whether it had one | `Show#primary`, `Show#back` |
| `pad`, `start` | a gamepad's X, Y, LB, RB, LT and View/Select, and Start | `Show#pad`, `Show#start` |
| `key_bindings`, and the `type`, `paste`, `buy` they name | the keys it takes itself, in order (`KeyBinding`): a typed key (H on Home, C on Settings, the keypad's digits, a license key), Ctrl+V and Ctrl+B | `InputHandler#call`, before its own `KEY_BINDINGS` ([input.md](input.md), "Keyboard") |
| `scrolls?`, `stick_scrolls?`, `scroll`, `line` | whether its list scrolls, whether the left stick scrolls it too, how far it is scrolled, and by how much a notch moves it (`Screens::Scrolling` keeps a scrolling screen's scroll, and the drag and row press of a press on it) | the wheel, keys, drags and sticks; `InputHandler#read_with_stick`, and `App#repeat_keys` |
| `waits_for_release?` | whether a press waits to be let go, as Game Over's pile does | `InputHandler#press` |
| `covers?`, `announces?` | whether it covers what is under it, and whether a title change's announcement shows over it | the renderer, and the friend groups' announcements |

A screen keeps its own state: the dialog its achievement, the share preview its text, the offer what it leads with, Stats its hold and Undo, each scrolling screen its list's scroll and the drag on it, the Tutorial its scene, the new-theme card the moment it first showed, Home its plan and the controller's ask to quit. The friend groups' pages are `GroupPanel`'s, inside `Screens::FriendGroups`, and it asks the stack whether they are open. The `Show` keeps what is not a screen: the game's feedback (the clock's lead-in after the Tutorial among it), the stack, and the use cases; and, until the painters take the screens' drawings, a method for each value a painter reads from a screen.

**Drawing.** `Shell::Renderer#draw` draws the screen for the state's ground (Home's drifting dots, the Tutorial over its game, or the game and Game Over over its pile), then the screens over it from the last that covers the rest (`covers?`: the screens over Home, Friend groups, the offer) up to the top one, each with its veil and painter, and a title change's announcement where the top screen shows one.

**Adding a screen** touches, as a throwaway one over Settings showed: its class in `screens/` (what it answers, its buttons, its presses); its line in `presentation.rb`'s load list; its line in `Screens::ALL`; the screen it opens from (a button there, placed in that screen's layout and named in `Style::WORDS`, and the press that opens it, `Show#open_layer`, or `Show#open_page` for a screen over Home); its painter, with its line in `shell.rb`'s load list; and the renderer's choice of painter for it. `test/presentation/inputs_test.rb` fails until every input reaches it and every control it answers is reached, and `test/presentation/screen_answers_test.rb` until a table says what each press does on it.

**Where the chains once disagreed.** Before the screens were objects, the `Show`, `App` and the renderer each chose the screen on top in their own order. Where they disagreed, the screens now agree, each as the books in `INSIPIRATION.md` decide (`test/presentation/screen_answers_test.rb` holds each):

1. **Y buys on the offer over Game Over**, as its "(Y)" says (it did nothing). A button names the action it takes, so the label must be true wherever the button shows (Podmajersky, *Strategic Writing for UX*). The offer is a screen of its own, veiled over Game Over and labeled, so Y there is an obvious mode, not a hidden one (Saffer, *Microinteractions*: make a mode obvious). And a reflexive second Y, meant for Share my score, ends at the store's own confirmation, which makes the wrong action hard (Lee and Wickens, *Designing for People*). The owner left this one to the books.
2. **The new-theme card takes no controller button meant for Home under it** (X, Y, LB, RB, LT and View opened Home's screens and How to play under the card). The card is a mode that waits for its answer (Saffer), and a press that acts on a screen the player can't see is an error the design invites rather than prevents (Lee and Wickens).
3. **The card takes no H meant for Home** (H started How to play under it, and spent a Free player's game): the same mode, and the same error, with a cost.
4. **Nothing scrolls hidden under the offer** (the wheel, keys, sticks and a drag moved the list under it). A change behind a screen that covers it is a change where the player isn't looking, and is missed (Johnson, *Designing with the Mind in Mind*); input belongs to the screen in view (Saffer).
5. **Empty space pops one of Home's dots only on Home** (Themes, Privacy, Change Server, the offer and the card played a pop for a dot under their veil). The toy is Home's, where its dots are in view (Schell's lens of the toy); under a veil the dots are scenery, and a pop the player didn't aim at is feedback for nothing they did (Saffer: feedback that fits the moment; Swink, *Game Feel*: feedback says what happened).
6. **A title change's announcement is drawn once** (it was drawn twice on Game Over and its share preview): feedback never more than it needs to be (Saffer).
7. **An announcement starts only where it is drawn** (it could pass unseen on a screen over Home or under the offer): attention is scarce, and an announcement shown where it can't be seen is lost (Hodent, *The Gamer's Brain*; Johnson). It can now show some time after the title changed; its words say what happened, so it is still true then.
8. **An achievement's dialog holds every input while it is open**: the wheel, the keys and the sticks scroll nothing of the grid under it (they did, while a tap beside the card closed it). The dialog is a mode, and Saffer's rule for a mode that can't be avoided is to make it obvious (*Microinteractions*): what the player presses belongs to the card in view, as a tap beside it already did, and a grid moving behind the card is a change where the player isn't looking (Johnson, *Designing with the Mind in Mind*: we miss what we don't expect).

## The setdef splash

Before Home, setdef's logotype shows on its near-black: "setdef" in Iosevka Bold (`Style::TYPE.wordmark`, `assets/fonts/Iosevka-Bold-setdef.ttf`), then a solid block like a text cursor. It follows setdef's brand file (`brand/README.md` in setdef's repository), which is the authority for how the mark looks and behaves.

**Colors.** The mark is `Style::SPLASH_YELLOW`, `#fbbf24`, on `Style::SPLASH_INK`, `#09090b`.

**Measures** (`Presentation::Logotype`), all in ems of the font's size:

| Measure | Value |
| --- | --- |
| a letter's step (`ADVANCE`) | 0.5, one Iosevka cell, no tracking |
| the block's width (`BLOCK_WIDTH`) | 0.5, one cell |
| the block's top and bottom (`BLOCK_TOP`, `BLOCK_BOTTOM`) | 0.81 above the baseline to 0.14 below it, 0.95 tall |
| the gap after the "f"'s cell (`BLOCK_GAP`) | 0.5 / 7, about 0.0714 |
| the whole mark (`WIDTH`) | about 3.57 |

These numbers are the maintainer's decision, kept in the font's own unit so they can be checked. `Logotype.fit` sizes the mark in whole units to 78% of the window's width (70% on an upright screen) and at most 60% of its height, and centers the block's middle on the window's. `SplashPainter` puts letters and block on whole device pixels.

**Glow.** The mark, letters and block together, is blurred in its own color at 55% under the crisp mark (`GLOW_STRENGTH`). The blur's standard deviation is 0.06 em (`GLOW_SIGMA`), matching the brand artwork's filter. `Logotype#glow` builds a `BloomStyle` for `Shell::Bloom` of three passes at a sigma of 3 blurred pixels (`GLOW_PASSES`, `GLOW_STEP`), with the blurred layer's resolution set so that comes to 0.06 em in device pixels at every window size and density. `SplashPainter#refresh` rebuilds it on a resize. The glow is added to the ground. Where there is no blur shader, there is no glow. The block's glow follows its own lit level, so it glows exactly when it is lit; the maintainer's rule: "The block cursor glows exactly when the letters glow, and is flat when they're flat."

**Timing** (`Presentation::Splash`):

- It fades in over 0.25 s (`FADE_IN`) and out over 0.3 s (`FADE_OUT`), showing Home under it as it goes.
- With sound on, a jingle of six ticks plays over it at 120 beats a minute (`JINGLE`: beats 0, 1, 3, 3.5, 4 and 5, pitches 1.2, 0.9, 1.2, 0.9, 1.0, 0.8). The splash lasts the last note plus two beats, 3.5 s (`SOUNDING`), so it ends on a dark block held long enough that the fade to Home is not taken for the cursor fading.
- Muted, it lasts 1.4 s (`SILENT`), long enough to read the name.

**The blink.** With sound on, each note flips the block, like an amber terminal's cursor: lit from the first note to the second, dark to the third, and so on, so the sixth leaves it dark. It lights in 0.03 s (`LIGHTS`) and fades in 0.1 s (`FADES`), like a phosphor. The shortest dark span, 0.25 s between the fourth and fifth notes, outlasts the fade. Muted, the block stays lit: there is no music to flash to. With `DOT_POPPER_CALM=1` it also stays lit, as the brand says a blinking mark stops under reduced motion; the jingle still plays if sound is on.

**Skipping.** A tap, click, key, gamepad button, or either trigger pulled to where it would press, ends it (`App#skip_splash`), and that press goes no further, so it can never touch the game. `DOT_POPPER_AUTOPLAY` (the bot), `DOT_POPPER_SCENARIO` (the GUI scenario runner) and `DOT_POPPER_NO_SPLASH` leave it out (`Splash::SKIPPED_BY`). Tests: `test/presentation/splash_test.rb`.

## Home

Home reads top down: the game's name, Play, today's goal with the days in a row, four large buttons, then a bottom row of small pills. One entry point and few choices (Hick's law, from Lidwell's *Universal Principles of Design*).

### What it shows

| Part | First launch | After a game |
| --- | --- | --- |
| the name | yes | yes |
| the legend (the scoring, in signs) | yes | no |
| Play | yes | yes |
| today's goal and the days in a row | no | yes, except on the smallest windows |
| Stats, Achievements, Themes, Friend groups | no | yes; Friend groups only where a group server is offered |
| How to play | no | yes |
| Settings | yes | yes |
| Quit | on a computer | on a computer |

"After a game" is `Show#stats_offered?`: a game has finished, or the player cleared their Stats (`StatsBackup#cleared?`), since clearing does not make them a new player. A first launch shows only what is needed to begin (Hodent: one thing at a time); Play already teaches the game, so How to play waits until after the first game. `test/presentation/redesign_test.rb` checks that a first launch offers only Play and Settings (and Quit on a computer).

- **The name** is set as large as fits: from `TYPE.game_name` (108, scaled) it shrinks until it fits 96% of its width (at most 615 units across on a wide window, `NAME_WIDTH`), and grows while it fits and stays under 28% of the safe area's height (`HomeScreen#name_size`). A theme with art draws it with `Shell::ThemedName`; otherwise it is the candy lettering.
- **The legend** (`Presentation::Legend`) is the tutorial's signs without a word: a bright dot, then "+1" and "+1" with a stopwatch; under it a popped dot, then "−2" and "−2" with a stopwatch, the numbers in two columns. Its type is `TYPE.legend` (29, scaled). See [tutorial.md](tutorial.md) and [ADR-0003](../adr/0003-how-to-play-is-taught-without-words.md).
- **Play** is the screen's filled gold button (see "The one main button"). Where games are counted ([ADR-0012](../adr/0012-free-games-20-then-3-a-day.md)), a second line under its word says "23 games left"; with none left it says "Get Pro", with "No games left today. 3 more tomorrow." under it, and opens the offer (`Show#play_word`, `#play_note`, `Screens::Offer#open_for_play`).
- **Today's goal** is a card: "Today's goal" and a check once met, the goal's whole sentence in up to two lines, and at the right, after a divider, the days in a row as a gold number over "days in a row" (`HomePainter#goal`). The sentence is never cut short: like a large button's words, its type shrinks until it fits in two lines above the card's bottom, down to 11 (`Presentation::GoalCard`), and Home shows the card only where every daily goal fits so (`GoalCard.room?`). What the goal and the streak are is in [progress.md](progress.md).
- **The large buttons** (`Show#tile_names`) each show an icon, a name and one value (Saffer: bring the data forward):

  | Button | Icon | Value |
  | --- | --- | --- |
  | Stats | bars | "Your record: 27" |
  | Achievements | ribbon | Pro: how many are earned; Free: "10 to earn" |
  | Themes | a bright dot | the current theme's name |
  | Friend groups | crown glyph | "1 of 3 titles" for a member; otherwise "Join or create" |

  With a controller, each carries its button in its corner: X, LB, RB, LT.
- **The bottom row** (`HomeScreen#pill_row`) is quiet pills, each as wide as its icon and word: How to play (a circled question mark), Settings (a gear), and on a computer Quit (the power sign). Where the row is too wide for the screen, every pill narrows alike.

### How it is laid out

`HomeScreen#plan` gives a `HomePlan`: a Rect for the name, legend, Play, goal card, each large button and each pill, the name's and the legend's type sizes, and `quit_line`. It has three layouts:

- **Upright or wide** (`#upright`): the bottom row a margin above the safe area's bottom, the large buttons above it in as many columns as there are buttons where each has 170 units for its words (always, on a window 900 wide or more that is not short), otherwise two; the goal card above them; then Play and the name. On a wide window Play is 560 × 104 and the card at most 768 across; on a narrower one both span the page. On a first launch the name, legend and Play stand as one group, 42% of the way down the room above the bottom row (`#centered_play`).
- **Tighter.** Where the mocks' spacing does not fit (some part leaves the safe area, two overlap, or a daily goal would not fit whole on the card), Home tries again with smaller gaps and buttons (`tight` 1), and then also without the goal's card (`tight` 2), which Stats shows too (`#upright`, `#fits?`).
- **Short and sideways** (`Layout#short?`: a safe area under 520 tall and wider than tall): the name and Play on the left half (at most 398 across), and the goal card, the large buttons two by two and the bottom row on the right, their heights shared out to fit (`#landscape`, `#shares`); where the card is too narrow for every daily goal whole, it is left out and the large buttons and the bottom row share its room. A first launch puts the name, legend and Play on the left (`#first_landscape`).

The margin is `Layout#page_margin`, 16 on a phone (a safe area under 600 on its shorter side, `Layout#phone?`) and 24 elsewhere. `ScreenPlansTest#test_homes_parts_never_overlap_or_leave_the_safe_area` checks every part, first launch and after, with three large buttons or four, with and without Quit, at fifteen window sizes and every desktop size from 400 × 320 to 3840 × 2160. `#test_homes_goal_card_shows_every_goal_whole` checks, at the same sizes, that every daily goal's whole sentence is what the card draws, in two lines that stay on the card, and that phones and roomy windows keep the card.

### Play, the dots and the keys

- A tap on one of Home's bright dots pops it for fun, with its droplets, ring and sound, and scores nothing (`Screens::Home#empty`). Empty space does nothing, and on every other screen a tap on a dot showing through does nothing.
- Enter, Space, a gamepad's Start, and its A aimed at no button press Play (`Show#primary`). Only "(A)" is shown.
- H, or the gamepad's Y, opens How to play. M mutes, on any screen. On a gamepad X opens Stats, LB Achievements, RB Themes, LT Friend groups, and View/Select opens Settings (`Show#pad`, `GamepadButtons::SETTINGS`), as a console game's options button does.
- **Quitting.** On a computer, Quit quits at once: a press on a labeled button is deliberate, so it asks nothing. On Android, Back leaves the app from Home. iOS leaves quitting to the system. A controller's B, and a computer's Escape, ask first: the first press plays a tick and shows "Press B again to quit" (or "Press Escape again to quit", naming the key that asked; `Show#quit_again`), and a second press of either within two seconds quits (`Show#ask_to_quit`, `QUIT_ASK`), so a stray press never closes the game. The line fades out over its last 0.3 s (`#quit_prompt`). It stands at `HomePlan#quit_line`, midway between Play's bottom and the part below it, and `HomeScreen#fits?` keeps a 200 × 18 box there clear of everything, so Play never moves for it.

### The window choice on computers

On a Mac, Windows and Linux the Show gets a `Shell::DesktopWindow`; on phones and tablets a `Presentation::NoWindowControl`, whose `offered?` is false, so Home shows no Quit and Settings no Display row: the game fills their screen already. `DesktopWindow#display` is `:window`, `:borderless` (LÖVE's desktop fullscreen) or `:exclusive`. F11, and Alt+Enter (Cmd+Enter on a Mac), switch between the window and the last fullscreen choice. Saffer: a control people need must be discoverable, not only a shortcut; and Lidwell: give people control of their exit.

## Settings

Settings holds what most visits never touch (the 80/20 rule, Lidwell). It is a heading and Back, then rows, each a label with a small mark and a pill of choices, the chosen one filled in cream with dark words (`Shell::ChoiceRow`):

| Row | Choices | Shown | Controller |
| --- | --- | --- | --- |
| Sound (speaker) | On, Off | always | Select |
| Dot size (a bright dot) | Standard, and Bigger or Smaller by what it does here | where the two sizes look different, or wherever Bigger or Smaller is saved | LB |
| Display (corners) | Window, Borderless, Full screen | on a computer | RB steps through them |

Then two pills, Credits and licenses (X, or the C key) and Privacy (Y), and under them, only while setdef is gone, Change Server ([ADR-0011](../adr/0011-pro-outlives-setdef.md)).

- **Laid out** by `SettingsScreen#plan`: on a safe area 620 wide or more, labels in a left column (28% of the width, at most 226) beside their choices, the whole at most 928 across and centered down the page, with Credits and licenses and Privacy side by side; narrower, each label above its choices and every pill the page's width. A page too short for all of it scrolls, by the wheel, the keys, a drag or the right stick, and only the buttons in view take presses (`Screens::Settings#controls`; `settings_test.rb`).
- **Dot size.** The first choice is "Standard", the default, worked out from the screen, and the second the bigger or smaller size, named by what it does on this screen next to Standard: "Bigger" on a phone, "Smaller" on a big monitor (`Show::SIZINGS`, `Words#sizing`; [ADR-0020](../adr/0020-standard-dots-are-sized-to-the-screen-by-default.md)). The maintainer: "A player sees only their own relative dot sizes: the smaller option, and the bigger option." So the words say what happens on the screen the player has (Podmajersky; Yifrah: what will happen, not how the system works), and one player sees two names, Standard and one other, each meaning one thing wherever it appears ("Standard" on Settings, Stats and the shared result alike). Each choice starts with a bright dot drawn at the size it gives, the bigger or smaller one 0.16 of the row's height in radius and Standard's in true proportion to it, kept between half and 2.2 times as big (`SizingPreview#icon`, `Style::SIZING`): Tidwell's Preview pattern. Where the two sizes are within a tenth of each other and Standard is saved, the row is left out (`SizingPreview#offered?`): the 80/20 rule and Hick's law (Lidwell) favor showing fewer choices, and there this one would change nothing a player could see. Where the bigger or smaller size is saved, the row always shows, alike or not, so a player is never left with a setting no control shows or lets them leave: a hidden mode (Saffer, *Microinteractions*: avoid modes, and make one obvious when you can't), which only recall could undo (Johnson, *Designing with the Mind in Mind*: recognition over recall; Lee et al., *Designing for People*: make the right action obvious). There the second segment says "About the same", the words the game already had for sizes within a tenth (`Words#sizing`): neither "Bigger" nor "Smaller" would be true, and these say what the player will see (Yifrah, *Microcopy*), as the two nearly equal dots beside them show. Once a size is chosen, the row stays for the rest of that visit (`Screens::Settings#sizing_shown?`), so choosing Standard there never pulls the row from under the finger; the next visit leaves it out. It is worked out afresh from the window each time, so a resize brings the row back or takes it away. Choosing saves `dot_size.txt` and respawns Home's dots at the new size, which show through the veil at once; choosing the chosen one again only ticks (`Show#choose_sizing`). So a player who reads no English still sees two dots, one bigger, and which is filled: the preview, not the words, says what each does. Where the two sizes look different, Stats says "Stats for standard dots" (or "bigger", or "smaller", by the segment's name) under its heading (`Show#stats_note`); where they look alike it says nothing there, even while the row shows because Bigger or Smaller is saved.
- **Sound** sets the mute that M toggles (`Screens::Settings#set_sound`).
- **Display** sets `DesktopWindow#display` at once.
- **Privacy** is two lines with their marks ("Your Stats stay on this device." and what a friend group keeps online), "Read the privacy policy", which opens https://dot-popper.setdef.com/privacy (`Show::PRIVACY_URL`; X on a controller), and, for a player the group server knows, "Delete my friend group data", held to confirm, with "Your Stats stay." under it (`PrivacyScreen`). What is kept is in [privacy.md](privacy.md) and [ADR-0014](../adr/0014-privacy-facts-come-from-the-code.md); the deletion in [friend-groups.md](friend-groups.md).

## Stats

Stats opens from Home's Stats button. Under its heading, and the dot-size note where it applies, the screen is cards in a list that scrolls: the highest score with a bar chart of the last games, the records, the daily goal and its days in a row, and the totals (`StatsLayout`, `Shell::StatsPainter`). One column on a phone, two on a window 900 wide or more (the chart and goal left, records and totals right, each at most 552 across), three on a short window. Each row has its label on the left and its number on the right, so numbers line up and can be scanned down (Redish; Johnson on proximity). Back is in the bottom left (top left on a short window), and "Clear my stats…", or Undo after clearing, in the opposite corner (`Layout#clear_stats_button`, `#undo_button`). With nothing played, it says "Play a game, and your stats will appear here." What each card counts, the chart's dimmed bars, and clearing by a held press are in [progress.md](progress.md).

## Achievements

A grid of icons, each the achievement's sign in a circle and its name under it (`AchievementsScreen`). The radius is 56, 44 on a safe area under 600 wide, 36 on a short window; as many columns as fit at three radii each, at least two, with a short last row centered, scrolling where it is taller than the page. An earned achievement is a gold disc with a cream rim; one not yet earned sits in a dashed ring (`AchievementsPainter#emblem`). For Pro the heading has the count earned under it. With a controller, "How to earn (X)" stands in the bottom right corner and X opens the first.

A tap opens a dialog over the grid (`AchievementDialog`): the sign, the name, how to earn it, and for Pro either the day it was earned or "Not earned yet", with a progress bar ("Your record", "19 of 20") for the four the game measures (Steady hand, Unshaken, Big score, Long haul; `Show#achievement_progress`). Recognition over recall (Johnson). The card is at most 520 across. Its buttons are Close, and for a Free player a filled "Get Pro" before it; with a controller, LB and RB step to the previous and next achievement. A tap beside the card, Escape or B closes it. What each achievement is and how it is earned is in [progress.md](progress.md).

## Game Over

Game Over shows over the finished game's pile ([look-and-sound.md](look-and-sound.md); dragging it in [input.md](input.md)). It leads with Play again, so another game is one press (Juul; Swink).

### What it shows, top down

1. "Time's up!" (`TYPE.heading`, 64), sliding in.
2. The score (`TYPE.final_score`, 136), counting up over 0.8 s (`Style::GAME_OVER.tally`).
3. The record line: "New record!" glowing, once the score has counted, or how far short it fell ("Just 2 points short of your record of 27", "Your record is 27", "You tied your record of 27"), or "Your record: 18" for a size class's first game (`Words#short_of_score_record`; [progress.md](progress.md)).
4. **The facts**, each a sign and a number: a bright dot and the dots popped, a popped dot and the mistakes, and the game's stopwatch and how long the game lasted, "34s", as the game's own "+1s" (`Words.facts`). Nothing in them needs reading English (`AGENTS.md`), and each is told by a sign, not color alone (Westland & Maggio). They stand in one row, or one under another where the row is too wide for the room (`GameOverScreen#facts`).
5. Any other record the game set (the most impressive one, `Stats::Record::ORDER`), as a sentence: "New record: 18 dots in a row without a mistake" (`Words#record`).
6. **Lines in pills** (`GameOverChip`, `Show#game_over_chips`), each with its mark: today's goal met (a check), a new achievement (a ribbon), and what the game did in a friend group (the crown glyph). The achievement's and the group's open what they name, the achievement in its dialog and the group whose title the game took, and carry an arrow (`Screens::GameOver#open_from`; LB and RB on a controller). Today's goal met opens nothing (Saffer: feedback no bigger than the moment); it gets a burst of twinkles. A Free player's game hears of no achievement here: what it earned is kept and shown once Pro is bought (`UseCases::FinishGame`). A pill too narrow for its words ends them with "…".
7. **Play again**, the filled gold button, at least a main button's size (`Layout#primary_size`), 104 tall (100 on a phone) at full type, at least 560 across where there is room, with "23 games left" under its word where games are counted. With no game left it says "Get Pro" and opens the offer (below).
8. **Home** and **Share my score** side by side under it, each as wide as its words, Home first.

Play again is drawn at 35% until Game Over will take a press (`Rules::GAME_OVER_GRACE`, 0.9 s), then fades in; until then a press on it does nothing (`Show#play_again`). So a tap meant for a dot in the last instant of a game cannot leave Game Over (Lee and Wickens, *Designing for People*: error prevention before error recovery). Home and Escape (and B) go Home once the grace is over (`Screens::GameOver#continue_on`). Enter, Space, Start and A aimed at nothing press Play again. A press anywhere else belongs to the pile (Schell's lens of the toy). The HUD goes once Game Over's heading has arrived (`Shell::Renderer#draw`), since the score is on screen.

**Share my score** is a dark pill outlined in a bright dot's gold with a share glyph, three dots joined by two lines (`Shell::ShareButton`), quieter than Play again's fill. It is hidden until the score has counted up; then it rises 12 units into place with a slight overshoot and a gold ring spreads from its edge (`Style::GAME_OVER.share`, `ShareButtonEntrance`). On a new record it waits 0.15 s more, rises 28 units, and rings brighter and wider. Its reach does not move while it rises. Motion as the score lands draws the eye at the moment a player is proudest.

### How it is laid out

`GameOverScreen#plan` stacks the blocks in a `Column` (see "Layout plans") and gives a `GameOverPlan`. The room runs from a margin under the safe area's top to a margin above its bottom, or to a radius above the window's floor if that is higher (`#room`), so nothing covers more than the upper half of a dot lying on the floor: the pile shows how the game ended, and half a dot shows its fill or its ring plainly. Short of room the type shrinks first; then lines go in this order: the record (rank 2), the facts (3), the pills (the last first, 3.8 to 4), the record line (5), and "Time's up!" (6). The score, Play again, Home and Share my score always stay. A line wider than the room is left out. A short window held sideways puts "Time's up!", the score and the record line in a left column (38% to 50% of the room) and the rest in a right one, at one shared type scale (`#sideways`).

Gaps above each block at full size (`GAPS`): heading 26, score 4, record line 4, facts 14 (4 between stacked facts), record 8, each pill 10, Play again 34, the buttons' row 14. A pill is 38 tall (at least 30) with 15-unit words (at least 12). The facts' type is the summary's (`TYPE.summary`, 20) plus 3.

The plan also gives `backing`: the bounds of everything above Play again, cut to the safe area less the backing's padding and feather (`Style::GAME_OVER_BACKING`: 60% at the middle, feathered over 40 units in ten layers, padded 18). Its tests require it to end above Play again, so Play again stands on the pile. `GameOverPainter` draws the parts "as the mocks draw it, with no backing of their own", and no painter draws `backing`.

`ScreenPlansTest` checks Game Over at fifteen window sizes, with and without a new record and another record, and none, one or three pills: everything fits, nothing overlaps, everything stays inside the safe area, Home comes before Share my score, and Play again and Home end no lower than a radius above the floor. It also checks the order lines are dropped in and that the facts stack where their row does not fit. `redesign_test.rb` checks that Play again starts the next game and Home goes Home, and that the achievement's line opens it while the goal's opens nothing.

### Get Pro opens the offer over Game Over

With no game left, the main button says "Get Pro". Its press opens the offer over Game Over, leading with games and noting "No games left today." (`Screens::Offer#open_for_play`), as every Pro feature's offer opens over the screen it was pressed on. Back closes it to Game Over as it was. While the offer is open, nothing under it takes a press, drags the pile (`Show#waits_for_release?`), or opens Share my score. The offer is drawn over the finished game veiled at 90%, as over Home's dots (`Renderer#draw_screen`).

## Sharing a score

Share my score (Y on a controller) offers the game's result as text, through the `sharing:` the Show is given (`Screens::GameOver#share`). The text is `Words#share_text`:

```
Dot Popper: 25 points, a new record!
New record: 18 dots in a row without a mistake
🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds
Played with standard dots.
```

### On a phone: the system's share sheet

On iOS and Android (in the phone host, `Platform#phone_host?`), the text goes to the system's own share sheet and no preview opens. Players on a phone expect the phone's sheet, which reaches messages, chats and notes in one tap. `Presentation::SheetSharing` opens `dotpopper-share://score?text=…`, the text percent-encoded as RFC 3986's unreserved characters (a space `%20`, a plus `%2B`), and the app's host catches that URL before it leaves the app. How the hosts do it, and why, is [ADR-0008](../adr/0008-native-features-live-outside-the-ruby-process.md) and [doc/ios.md](../ios.md), "Share my score". If the host refuses the URL, `open_url` answers false and the preview opens instead.

### On a computer: the preview

Everywhere else (`InGameSharing`), Share my score opens a card over Game Over that shows exactly the text that would be shared, and copies nothing yet: a button named Share that quietly replaced the clipboard would surprise people, so Copy is the player's own choice. The card holds "Share your score", the result in a message bubble, left-aligned as it will read when pasted, a line's room for "Copied! Paste it anywhere." with a check, and Close beside Copy (`ShareScreen`, `SharePlan`, `Shell::SharePreviewPainter`).

- **Copy** is the card's filled gold button and the only press that writes the clipboard (`Screens::SharePreview#copy`). Enter, Space, Start, A aimed at nothing, and Y again all copy. Then the confirmation fades in where its room was kept, so nothing moves, and the card stays open until closed. The confirmation is the card's only sentence besides the heading: it tells the player that something invisible happened and where it can go next (Strunk: omit needless words).
- **Close**, Escape, B, and a tap or click beside the card close it, back to Game Over as it was (`Show#close_share`). The preview is the presentation's alone (`Show#sharing?`): the game stays on Game Over, its grace runs as before, and nothing under the card takes a press.
- **Drawing.** Fredoka has no emoji, so the bubble draws 🟡 as the game's bright dot, ⚫ as a popped dot and ⏱ as a small stopwatch, each 1.15 of a line's height across (`ShareGlyphs`); the copied text keeps the real emoji. A line of facts breaks only after a "·", so "1 mistake" stays whole, and lines are balanced so no word is left alone (`ShareScreen#wrapped`, `Words.balance`).
- **Size.** The card is as wide as its widest line needs, never narrower than Close and Copy at their widest (3.4 heights each), and at most 680 units at a `ui` of 1 (`Style::SHARE_PREVIEW`), padded 24, the bubble padded 14 (half again at its sides). Short of room the type shrinks, then the heading goes; the message, the confirmation's room and the buttons always stay. It comes in over 0.22 s, lifting 14 units, over the screen veiled at 60%.

`ScreenPlansTest#test_the_share_preview_never_overlaps_or_runs_off_screen` lays out the longest result at fifteen sizes in the mouse's and the gamepad's words; `share_test.rb` checks the sheet's URL, the fallback, and the button's entrance.

## Credits and licenses

Credits opens from Settings' "Credits and licenses" (X, or C), and Back, Escape and B go back one step, to Settings. The app stores want licenses readable inside the app, since players cannot open the app's folder, and players expect a Credits screen.

**What it says** (`CreditsText.compose`, the words in `Style::WORDS.notice`), in order: "Made by setdef" (and a line of thanks once `thanks:` has one), "Dot Popper © 2026 setdef" and "All rights reserved." ([ADR-0015](../adr/0015-all-rights-reserved-after-v0-9-9.md)), then under "Open-source licenses": Fredoka and its OFL, Iosevka and its OFL, Noto Emoji (the tutorial's pointing hand) and its Apache license, imsky/wordlists (friend groups' names) and its MIT license, Lota's `NOTICES.txt`, and Fledge's notices. Each license shows only if the running build carries it, and a heading left over nothing is dropped (`CreditsText.bare`).

**Finding the texts** (`Shell::NoticeFiles`). The fonts', the emoji's and the wordlists' licenses are read from the game's own folder (`assets/fonts/OFL.txt`, `assets/fonts/Iosevka-LICENSE.md`, `assets/emoji/LICENSE.txt`, `assets/wordlists-LICENSE.txt`). Lota's `NOTICES.txt` and Fledge's `notices/` folder are looked for in the game's folder and up to four folders above it, and above the running program's folder, nearest first (`REACH`), because the fused layouts differ by platform: `NOTICES.txt` lands at the top of the app's `app` folder, Fledge's `notices/` beside `app` on a computer and with the game's own files on a phone. Of `notices/`, the top level's `.txt` files are read, `NOTICES.txt` first. Searching upward finds the files without knowing the platform, and a build with none of them still shows the rest. Platform layouts are in [platforms.md](platforms.md).

**How it reads** (`CreditsLines`, `CreditsLayout`, `Style::CREDITS`). Headings are bold and a size larger, subheadings bold in the gain color, notes in Fredoka SemiBold, and license bodies in Iosevka Regular (`TYPE.mono`), a monospace face that keeps the texts' columns and numbered clauses as their authors set them. The type is 20 units scaled (at least 11), lines 1.5 apart, in a column 680 wide scaled. A license written hard-wrapped (no line over 100 characters) is shown exactly as written wherever its widest line fits, and the column widens for it as far as the safe area allows. Otherwise its lines are joined back into paragraphs, a paragraph that is a list or indented keeps its lines, a ruled line is dropped, and each wrapped piece keeps its line's leading indentation (`CreditsLines.hang`), so a long clause continues under itself and nothing scrolls sideways. A word wider than the column is broken.

**Scrolling** (`CreditsScroll`). The page scrolls in a window between the heading and Back, by the wheel (three lines a notch), the arrows, Page Up and Down, Home and End, a finger's or the mouse's drag, and the stick or d-pad (14 lines a second at full tilt), which scroll here instead of moving the gamepad's cursor. A thin bar at the window's right edge shows where the page is. A resize keeps the same place on the page. `credits_test.rb` and `ScreenPlansTest#test_the_credits_screen_never_overlaps_or_runs_off_screen` check it; the GUI scenario `credits` plays it.

## What every screen shares

### Headings and Back

Every screen over Home has its heading and Back (`Shell::Header`, `Layout`). Back is 120 wide and a button's height (`Layout#control_height`: 56 on a phone, 60 elsewhere), in the bottom left of the safe area, or the top left on a short window, where a phone's thumb already is (`Layout#back_button`). The heading is 40 units (32 on a phone) and centered (`Layout#heading_place`): it shrinks until it fits the safe area less its margins, down to 18. On a short window it shrinks to fit centered clear of Back, down to 24, and where even that does not fit it sits centered in the room right of Back, down to 14. The content goes under the heading and clear of Back (`Layout#page`).

### Buttons name their action

A button names the action it takes (`AGENTS.md`; Podmajersky; Yifrah): Play, Play again, Home, Share my score, Copy, Close, Back, Quit, "Get Pro", "Use Ghost", Join and Create. With a controller, each button names the one that presses it (`ByInput`, `Words#for`): "Play (A)", "Play again (A)", "Home (B)", "Share my score (Y)", "Back (B)", "Settings (Select)", "Credits and licenses (X)". A finger's and the mouse's words are the same. The words follow the input the player used last (`Presentation::InputKind`, set by `Show#input=`): phones and tablets start with touch, computers with the mouse.

### The one main button

Each screen has one filled, warm button, a bright dot's gold with its word in the night's ink and a thin cream rim (`Shell::PrimaryButton`), so it reads at once as the thing to press (Tidwell, *Designing Interfaces*: one prominent primary action). It is Home's Play, Game Over's Play again, the share preview's Copy, the offer's Buy, the new-theme card's switch, a friend group's Join or Create in its notice, and a Free player's Get Pro in an achievement's dialog. Every other button is a quiet dark pill outlined in soft lavender (`Shell::PillButton`), a dark card (`Shell::Card`), or a row of choices (`Shell::ChoiceRow`). Play and Play again are at least a dot across and a button's height (`Layout#primary_size`: twice the radius, at least `Layout#button_size`, which is 52 scaled and never under 44), nearly the width of a phone, and a press reaches them a dot's width and a margin past their edges (`Layout#primary_reach`). Fitts's law: Play stays the biggest target.

`Show#primary` presses the open screen's main action, for Enter, Space, Start and a gamepad's A aimed at no button: the new-theme card's switch, Copy, Back on the Pro offer (Buy has its own controls, [store-and-pro.md](store-and-pro.md)), closing an achievement's dialog, the friend group's own, Back on any screen over Home, Play on Home, and Play again on Game Over. In a game it does nothing, since only a press at a place may touch the score.

### Reaches never overlap

Every screen's buttons are `Control`s (`lib/dot_popper/presentation/hover.rb`): a name, the `frame` where it is drawn, and the `reach` where a press lands on it, at least the frame. `Show#controls` lists the open screen's; taps and hover both go by that one list, so a button lights exactly where a click would press it. A quiet button's reach is a dot's width across and down at least, cut at the safe area's bottom (`Screens::Screen#button`).

`Control.apart` cuts the reaches so that no two share a point: where two overlap, the overlap is split halfway across the gap between the two buttons as drawn, along the way they are set apart, and each keeps its own drawn shape. On an edge two reaches share, a press goes to the button drawn nearer (`Show#control_at`). Empty space reaches nothing.

`ScreenPlansTest#test_on_every_screen_a_press_reaches_one_button_and_the_middle_of_each_reaches_it` walks a Show through the first Home, Game Over, the share preview, Home after a game, Stats with Clear and with Undo, Achievements and a dialog, Themes with and without a controller, Settings at its top and scrolled to its end, Credits and Privacy, at fifteen phone and window sizes and every desktop size with a window to control. On each it checks that no two reaches overlap, that a press at each button's middle reaches it, that no two buttons are drawn over each other, and that each is inside the safe area.

### Hover under the mouse

A button the mouse is over brightens its backing to the night's glow and its outline to cream over 0.12 s, and dims as quickly once the mouse leaves (`Style::HOVER`, `Presentation::Hover`), so moving between buttons never jumps; and the pointer becomes the system's pointing hand (`App#point_the_mouse`). Only while the last press was the mouse's: a finger or a gamepad never hovers (`Show#hovered`). A mouse user reads affordances from hover (Tidwell); a touch player has none to read, and a lit button under a resting pointer would mislead a gamepad player. `hover_test.rb` and `redesign_test.rb` check it; the GUI scenario `hover` checks the hand.

### Free and Pro look alike

Achievements, Themes and Friend groups carry no "(Pro)" and no locked look, and Home offers them to both players alike (Nielsen: consistency; Norman: a locked look is clutter). What differs is only what Pro has to show: the Achievements button's value, the count under the Achievements heading, earned marks and days in the grid and dialog (a Free player sees every achievement as not yet earned, `Show#achievement_earned?`), and Game Over's new-achievement line. A Free player's tap on what Pro brings opens the offer over the screen they are on, leading with the thing tapped (`Show#open_offer_for`, `#offer_focus`), and Back closes it to that screen as it was, so no one loses their place:

| Free player's tap | Opens the offer leading with |
| --- | --- |
| a theme on Themes, or the new-theme card's switch | themes (`Show#use`, `Screens::NewTheme#answer`) |
| Get Pro in an achievement's dialog | achievements, the dialog closing (`Show#achievement_pro`) |
| Join or Create on Friend groups | groups (`GroupPanel`'s `pro_offer`) |
| Play or Play again with no game left | games, with "No games left today." |

The offer opens whether or not a store answers; with none it says the store isn't answering. Leaving a group, deleting friend group data and clearing Stats never need Pro. `redesign_test.rb#test_a_free_tap_on_a_theme_opens_the_offer_over_themes_and_back_returns` checks it. The offer itself is in [store-and-pro.md](store-and-pro.md).

## Layout plans

Home and Game Over, and the share preview, never put a line at a fixed fraction of the screen. Each screen is a value (`HomeScreen`, `GameOverScreen`, `ShareScreen`: the `Layout`, the type, the words, a `measure`, and what the screen shows) whose `#plan` works out every part's Rect without Lota. The painters draw from the plan, and the Show takes every button's reach from the same plan, so what is drawn and what is pressed cannot drift apart. In the game `measure` is `Shell::FontMeasure`; in tests it is `RoughMeasure`.

**Blocks and `Column`** (`lib/dot_popper/presentation/column.rb`). Game Over and the share preview build an ordered list of `Block`s: a name, a measured height, the gap above it, a width (centered), and a drop rank if it is optional. A `Column` stacks them as one group centered down its room (or from its top). `Column#fit` asks for the blocks at each type scale from `Layout#type_scales`, 1.0 down by 0.05 to 0.7 (`Style::LAYOUT`: `shrink` 0.7, `step` 0.05), and places them at the largest scale where they fit. Where they do not fit even at 0.7, it first works out which optional blocks to leave out at that scale, the lowest rank first, and then grows the type back as far as what is left allows. A block without a rank always stays, even past the room's bottom. `Layout#type_size` never shrinks a size below 12 units unless it was already smaller. One column that every line goes through follows Tidwell's visual framework. `column_test.rb` checks it.

**Home** is laid out by `HomeScreen` itself rather than a `Column`, since its parts sit in rows and a grid: it tries the mocks' spacing, then tighter spacing, then without the goal's card, and takes the first that fits (see "How it is laid out" under Home).

**Laid out again only on change.** Home and Game Over each keep their last plan and lay out again only when the screen value differs from the last one (`Screens::Home#plan`, `Screens::GameOver#plan`). Laying out Home measures every line at every size it tries, about 0.7 to 1 ms on the maintainer's OnePlus Nord (measured, not enforced), and a frame asks for the plan more than once: to draw it, and for the buttons a tap or the mouse can reach. It changes only when the window, the words or the records do.

## The GUI scenarios and galleries

The GUI suite (`test/gui/scenarios_test.rb`, run by `rake test:gui`; see [ADR-0005](../adr/0005-gui-scenarios-play-the-real-game.md) and [development.md](development.md)) plays these screens in a real window: `game` (Home to Game Over to Home, Play again and Home), `share` (the preview, at 1200 × 800 and 400 × 850), `credits`, `stats`, `window_buttons` (Display and Quit by the mouse alone, also at 400 × 320), `dot_size` (at 400 × 850), `hover`, `words`, `how_to_play`, `purchase` and `themes`.

The galleries keep screenshots to look at, and check little: `redesign_gallery` (Home and the screens it opens at 1200 × 800, and at 400 × 850 and 850 × 400 by touch, and Home with a controller), `screens_gallery`, `offer_gallery`, `themes_gallery`, `games_gallery`, `website_gallery` and `home_gallery`. They are not part of `rake test:gui`. Run one with `DOT_POPPER_SCENARIO=<name> DOT_POPPER_GALLERY=<label>`.
