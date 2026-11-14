<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Friend groups: the game's side

How the game takes part in friend groups: where the server is, how the client talks to it, how members and groups are shown with no text from any player, the screens, and the announcements of a title change. For anyone working on `lib/dot_popper/groups` or the friend groups' screens. The server's rules (the title, the top score, group sizes, join codes) are summarized in [doc/server.md](../server.md), and its API is the server repository's `docs/api.md`. Why members are drawn icons and codes are digits is [ADR-0013](../adr/0013-players-type-no-text.md). What is sent and kept is declared in [doc/privacy.json](../privacy.json) and described in [privacy.md](privacy.md).

## Who can take part

Creating and joining a group need Pro: for a Free player, Join and Create open the offer of Pro over the friend groups' screen, leading with friend groups ([store-and-pro.md](store-and-pro.md)). Leaving a group and deleting friend group data never need Pro, so anyone can always get out. Competition is the draw, so everyone who takes part has Pro (the maintainer's decision). The game alone decides this, in `UseCases::JoinOrCreateFriendGroup`, which the `GroupPanel`'s Join and Create go through and which answers `:offer` for a Free player, where the panel opens the offer; the server does not check a purchase.

Only a game that counts is sent: one played by a member of a group, not the tutorial's, and with a score above 0, whatever its dot size (`Groups::Session#game_finished`, called as the game is finished, `UseCases::FinishGame`, with `counts:` false for the tutorial's game). The maintainer: "Somebody's gonna choose a dot size they like and stick with it, usually. Nobody who does that should be excluded from enjoying friend groups." The server is sent the score alone. Scores are not equal across devices, mice, fingers and controllers, nor across dot sizes; a player's own Stats keep each size's records apart, but a group compares every member's games as they were played. Dot sizing is in [rules.md](rules.md).

## The server's address

`Network::Server` (`lib/dot_popper/network/server.rb`) is the one place it is set, for friend groups, themes and setdef's own checks alike:

- `Server::SERVER_URL` is `https://server.dot-popper.setdef.com`, for every build.
- `DOT_POPPER_SERVER` names another server, to try one out; empty means none, and then the game offers no friend groups and makes no connection for them. A store build ignores it (`Build.settings`, [store-and-pro.md](store-and-pro.md)).
- An automated run (`Automation`) has no server unless `DOT_POPPER_SERVER` names a local one.
- While setdef is gone, a player may choose another server with Change Server ([store-and-pro.md](store-and-pro.md#when-setdef-is-gone)). `Composition::Root#server_url` gives friend groups and the themes check that server from the next start, and `Composition::Root#groups_session` keeps its token in `group-<host>.txt` so setdef's token, in `group.txt`, is never sent elsewhere.

The composition root (`Composition::Root`) builds the session with `Groups::Session.at(url, store:)`, or `Session.off` with no server. Home's Friend groups button shows only where a server is available (`Show#group_offered?`).

## The client

### Session

`Groups::Session` (`lib/dot_popper/groups/session.rb`, Lota-free) is what this device knows of its groups and everything it asks the server for. It is called only from the game's thread. What it last heard from the server (the groups, their title changes and history, whether the player was last known to be in a group, and the announcements and arrival still to take) is `Groups::ReadModel` (`read_model.rb`), which the server's answers replace; it decides only what to announce from them and when a group's history is worth reading again; what the game owes the server is `Groups::Outbox` ([Waiting games](#waiting-games)); `group.txt` is `Groups::GroupFile`.

- **Nothing is sent until a Pro player creates or joins a group.** A session with no saved token makes no connection. The first Create or Join first sends `POST /player`, which answers an anonymous token, and then the Create or Join. A player is only a token: no name, nothing they supply.
- **Every job comes from a declaration.** Each kind of request is one class in `Groups::Jobs` (`lib/dot_popper/groups/jobs.rb`), named for what it does (`NewPlayer`, `ListGroups`, `CreateGroup`, `JoinGroup`, `ReadGroup`, `ReadHistory`, `SendAchievement`, `LeaveGroup`, `SendGame`, `DeletePlayer`), which says what it sends and what each answer means: what is taken, what a refusal's status means for the player (`#refusals`), and which refusals it deals with itself. Its base, `Groups::Job`, takes the verb and path from `Groups::REQUESTS`, friend groups' own declarations, by `Network::Job.of`, which refuses a body whose fields differ from the declared ones ([privacy.md](privacy.md)). Adding a kind is its declaration and its class; `Session` answers only what every kind shares (no network, a 401, a 429, a loud job's error), and a job's answers reach it through its answer methods (`Groups::_Answers` in `sig/`).
- **What it asks for, and when**: the player's groups (`GET /groups`) at launch, when the screen opens, and again as [Asking again](#asking-again) says, once there is a token (`#refresh`); a group (`GET /groups/:id`) and its history (`GET /groups/:id/history`) when the player opens one (`#look_at`); `POST /groups` to create, `POST /memberships` with `join_code` to join, `DELETE /groups/:id/membership` to leave, `DELETE /player` to delete everything; `POST /games` with a score that counts; and `POST /achievements` with each achievement key a Pro player earns, once each, and those already earned on buying Pro (`UseCases::BuyPro`, told by `Entitlement::ProGranted`).
- **Scores are clamped** to 0 to 100,000 (`Outbox::HIGHEST_SCORE`).

### The low-priority thread

`Network::Worker` (`lib/dot_popper/network/worker.rb`) runs a `Link`'s requests in order on a thread of its own at priority -2 (`Worker::PRIORITY`), so a frame never waits on the network. The thread starts with its first job, so a player with no group has no thread. `Network::Link` (`lib/dot_popper/network/link.rb`) makes one HTTPS request at a time with `Net::HTTP`, OpenSSL's default certificate store, a 5-second open and 8-second read timeout, and a bearer token when the job sends one. It requires `net/http` and `json` on first use, on the worker's thread, so the game starts as fast as ever. `Network` is the game's HTTP client, which the request for theme releases and setdef's checks use too ([privacy.md](privacy.md#requests)).

**Nothing is handed to the worker during a game.** `Session#update(quiet:)` takes up finished replies every frame but starts waiting jobs only when `quiet` is true; `Show#update` passes `quiet: !playing?`.

### Asking again

A phone keeps a game's process for days, so what is asked only at launch goes stale: a theme the server releases, or a title change in a group. `DotPopper::Refresh` (`lib/dot_popper/refresh.rb`, Lota-free) asks for the player's groups (`Session#refresh`) and the themes released (`ThemeReleases#ask`) again when the game comes back to the foreground and when Home is shown after a game (it hears `Cabinet`'s `HomeShown`). It never asks while a game is in play or the tutorial plays over one; coming back during a game waits for Home after it. It asks no sooner than `Refresh::FLOOR` (five minutes) after the last ask, launch included, by the wall clock, since the frames' time stands still while the game is away; a clock set back asks at once. The server limits neither request. The same requests go out, with the same fields; only these two are repeated, and the proof, the license key's check, the connectivity checks and the store's first question stay once each start ([store-and-pro.md](store-and-pro.md)).

What comes back takes the road it takes at launch: a title change is announced from the history at Home or Game Over, and a new theme's card shows on Home ([look-and-sound.md](look-and-sound.md)).

The shell reports coming back as the window getting focus back (`Shell::App#focus`). On iOS, SDL takes focus from the window as the scene resigns active and gives it back as the scene becomes active (SDL 3.4.10's `SDLUIKitSceneDelegate` and `SDL_OnApplicationDidEnterForeground`); on Android, SDL's activity sends focus with `onWindowFocusChanged`; on a computer, it is the window's own focus. LÖVE's engine passes each as `Lota.focus`. The composition root makes the `Refresh` and subscribes it to `Cabinet`.

### Quiet failures

Whatever goes wrong in `Link` (no network, no certificates, a missing library, a page for a body) is `Reply.offline` or a refusal, never an error. Games play as ever.

- A job the player asked for (`loud`) leaves a reason in `Session#error` for the screen to show (`GroupWords.error`): "Can't reach the groups right now.", "No group has that code.", "That group is full.", "You are already in that group.", "You are in as many groups as you can be.", "Too many tries. Wait a while.", or "Something went wrong." Any other failure is forgotten until the next chance to ask.
- Each kind maps a status to a reason (`Job#refusals`): 429 for creating, joining or getting a token is too many tries (`Jobs::TOO_MANY_TRIES`), and 400, 404 or 422 for joining is no such group (`Jobs::JoinGroup::REFUSALS`). A 409's `error` is read by `Job::CONFLICTS`, for any kind: `group_full`, `already_member`, `group_limit`.
- A 401 to any job forgets the token and everything it knew (`Session#forget_identity`: the `Outbox` owes nothing and the `ReadModel` has heard nothing), as does a 404 to `DELETE /player`.
- A 404 for a group, its history or leaving it drops that group from the list.
- A game the server will never take (400, 404, 422) is dropped; so is such an achievement.

### Retry-After

A 429 starts a wait (`Session#wait_out`): the `Retry-After` header's seconds, 60 if it gives none (`USUAL_WAIT`), and an hour at most (`LONGEST_RETRY_WAIT`, 3,600 seconds). During it, Create and Join send nothing and say "Too many tries. Wait a while.", and waiting games and achievements wait too.

### Waiting games

What the game owes the server is `Groups::Outbox` (`lib/dot_popper/groups/outbox.rb`), saved in `group.txt`. If a counting game cannot be sent at once, the highest such score waits and goes with the next contact. Only the highest is kept: a lower game never replaces it, and it does not expire. It is owed until the server answers that very score, so a higher one that arrives meanwhile still waits. Leaving the last group drops it. Unsent achievement keys wait the same way. Nothing owed goes to a player in no group, nor without a token (a file that says the player is in a group but has none sends nothing), and each score or key is in flight once at a time. `test/groups/outbox_test.rb` holds the Outbox's own rules; the token, a 429's wait and leaving the last group are `Session`'s, held by `test/groups/session_test.rb`.

### What `group.txt` holds

One line each: the token, the unsent score, whether the player was last known to be in a group (`1`, or empty), for each group the newest title change shown and how the group looked then (`id|last|fingerprint`, separated by spaces), and the achievement keys not yet sent (separated by commas). `Groups::GroupFile` reads and writes it, leniently: a line missing or unreadable keeps its starting value, so a file with fewer lines, as only development builds before v0.9.10 wrote, reads too (every release with friend groups writes five). `test/groups/group_file_test.rb` holds it to examples of each line, byte for byte, and `test/groups/session_test.rb` to the files the game writes as it plays. After a launch with no network the groups are unknown, but a member's games still count (`Session#member?`).

## Identity: numbers, drawn

A member of a group is a number the server gives, in join order, never reused (`Groups::Member`). It is the only identity a player has: no name or anything else a player supplies, so there is nothing to filter, report or block. A group is known by its id. The game draws both and names both, from those values alone, so every device shows the same and the server stores no picture and no name.

**Member icons** (`Presentation::MemberIcon`, `lib/dot_popper/presentation/member_icon.rb`): a disc of two colors with a pattern, like an old GitHub identicon, drawn by the game (`Shell::MemberIconPainter`), with no emoji. A pattern is a choice of `FOLDS` (3, 4, 5, 6, 8), an `OUTER` motif (dots, petals, diamonds, spokes) and an `INNER` motif (dot, ring, star), 60 combinations (`COMBINATIONS`). A member's number walks those combinations by a step the group's id picks, coprime with 60, so numbers fewer than 60 apart never share a structure. A light or dark ground alternates along the same walk, so neighbors differ in grayscale too (Westland & Maggio: color alone never carries information). The colors come from eight `SCHEMES`, chosen for contrast at phone size. `MemberIcon.seed` is an FNV-1a hash, the same on every device and run.

**A group's crest** is the same drawing at number -1 (`MemberIcon.crest`). It shows beside the group's name in the list, over the group's screen, and on an announcement.

**Names** (`Presentation::Names`, `lib/dot_popper/presentation/names.rb`): a group reads plural and a member singular, from separate lists, so one is never mistaken for the other: "Brave Puffins", "Purple Kiwi". Group names pair a character adjective with a bird; member names pair a color with a fruit, and numbers fewer than `Names::COMBINATIONS` apart never share one within a group. The words are a hand-picked subset of Ivan Malopinsky's wordlists (MIT; `assets/wordlists-LICENSE.txt`, credited on the Credits screen), leaving out unkind words, words with a second meaning, and colors that also name skin tones; `test/presentation/names_test.rb` tries every pair against a list of bad words.

## The screens

`Presentation::GroupPanel` (`group_panel.rb`) holds the screens' state and `Presentation::GroupScreen` (`group_screen.rb`) lays them out under their heading and over Back; `Shell::GroupPainter` draws them. Their words are `Presentation::GroupWords`. The panel never waits on the session. Home's large Friend groups button opens them (on a controller, LT); its value is "1 of 2 titles" for a member, or "Join or create". The layout of Home is in [screens.md](screens.md).

| Screen | What it shows |
| --- | --- |
| The list ("Friend groups") | The player's groups, each a row with its crest and name and the crown glyph where the player holds its title, sorted by name; with none, "Beat your friends and take the title."; Join and Create. A row opens the group. |
| A group (its name as heading) | Its crest, its title line ("Score any points to take the title.", "You hold the title with 31.", "Beat 31 to take the title."), the standings (rank, icon, name, and "Champion" with the crown glyph or "You"), the join code hidden as "●●●-●●●●" with Show, then Copy, and History and Leave. |
| History | Every title change and every member's achievement, newest first: the member's icon, "Purple Kiwi took the title from Gold Fig with 31.", "The title passed to Purple Kiwi with 31." when the champion left and the server says (`passed_on`), or "Purple Kiwi earned Blink.", and when, in the player's own time zone ("November 8, 8:14 PM"). An achievement this game does not know is left out. With none, "Nothing has happened here yet." |
| Join with a code | The code box and the keypad. |

**Lists scroll**, in a window under the heading, by touch, mouse wheel or controller; they are not paged. Every button is a thumb's height, and Leave sits apart from the rest. Leave and delete are long presses (`GroupPanel::HOLD`, 2 seconds); letting go too soon does nothing.

Back goes up a level: History to its group, a group or the keypad to the list, the list out. Opening a group just created or joined happens by itself (`Session#take_arrival`). A group left or lost takes its screens with it.

### Joining by a seven-digit code

A group's code is seven digits (`GroupWords::CODE_LENGTH`), which the server makes. Digits, not letters, because no digits make a word in any language. The player taps it on a telephone's keypad (`Presentation::CodePad`): 1 to 9 in threes, then Delete, 0 and Join. A phone needs no keyboard, and a controller's cursor presses the keys as it presses any button. Where there is a keyboard, typed digits and Backspace or Delete work too (`GroupPanel#type`). The code box reads the code as it is shared, 482-1073, with a dash for each digit still to come (`CodeText`). Join looks disabled, and only ticks, until all seven digits are in (Podmajersky: say nothing the player can see). On a short window the box and the keypad sit side by side. Copy puts the code on the clipboard as 482-1073.

### Before a first Join or Create

A Pro player's first Join or Create opens a dialog over the friend groups' screen (`Presentation::GroupNoticeDialog`): "Dot Popper keeps your scores online so your friend group can see them.", a link, "Read the privacy policy", to `https://dot-popper.setdef.com/privacy` (`Show::PRIVACY_URL`), then Not now and a button that goes on (Saffer: at the moment it matters). That button says Join or Create, the word of the button the player pressed, since a button names the action it takes (Podmajersky). Where both words cannot share a row, the buttons stack, the one that goes on first.

Going on is remembered in `group_notice.txt` (`Presentation::GroupNotice`), so the dialog shows once ever, and clearing Stats leaves it. Not now sends nothing and asks again at the next Join or Create, since the player has agreed to nothing. A Join goes on to the keypad; a Create creates. A Free player's tap opens the offer of Pro first, and the dialog comes after buying.

### Controller labels

As everywhere, a free cursor and a labeled button for every action: on a controller each button's word names the controller button that presses it, as "Join (X)" (`GroupWords.pressed_by`). B is Back on every screen.

| Screen | Buttons |
| --- | --- |
| The list | X Join, Y Create, and RB opens the first group, from an "Open group (RB)" pill at the right of Back's row, since a row has no label of its own |
| A group | X Show, then Copy; Y History; LB and RB the previous or next group in the list's order, wrapping at its ends, from pills at the right of Back's row where there is another group; Leave becomes "Hold Start to leave", done by holding Start |
| The keypad | X Delete, Start Join; the digits are pressed with the cursor or typed |
| History | B only |
| The first-Join dialog | A goes on, B is Not now, X opens the privacy policy, as X does on the Privacy screen |

Enter, Space or A aimed at nothing joins on the keypad with a whole code, goes on in the dialog, and goes back elsewhere (`GroupPanel#primary`).

## Title changes

### Announcements from the title history

What is announced is read only from a group's history (`GET /groups/:id/history`), never from a game's reply. The history is fetched whenever a group's champion or top score looks different from when it was last read (`Group#fingerprint`, `ReadModel#title_moved?`), and the newest change already shown is kept for each group (`Groups::Seen`, in `group.txt`). So a reply lost on the way, or a retry, still ends in an announcement, and nothing is announced twice (Nystrom: one source of truth for an event). A group met for the first time announces nothing from before.

Only the newest change in each group is announced; the rest is in History (Saffer: feedback fits the moment; Johnson: attention is scarce). An announcement (`Groups::Announcement`) is one of three kinds: "You took the title with 31!", "A friend took your title with 31." or "A friend took the title with 31.". When the server says the title passed because its champion left (`passed_on` is true), it is "The title is yours." to the member it passed to and "The title passed to a friend." to the rest; it is not a win, so it never says "took". A change with no `passed_on` (a server that does not send it yet) is worded as a win. It shows for `GroupPanel::BANNER_SECONDS` (4 seconds), fading in and out over 0.4 s (`ShownAnnouncement::FADE`), at the top of Home or at Game Over, never during a game and not while the friend groups' screens are open, one at a time, on a dark pill with the group's crest and the new champion's icon. It asks nothing of the player.

### Game Over's line

After a game that counts, the server's answer to `POST /games` gives each group's result, and Game Over shows one line in a pill with the crown glyph (`GroupPanel#game_line`, `GroupWords.game_line`):

- "You took the Brave Puffins title!" for one group, "You took 2 titles!" for more;
- "You raised the bar!" when a champion beat their own score, which is no title change;
- "The title stays yours." when the player already holds every title the game could have won;
- "4 short of the title." for the fewest points short of a title.

The line opens the group whose title it took, when it took exactly one (on a controller, RB). While the answer is on its way the panel answers a blank, which Game Over leaves out, so the pill appears when the server answers. Game Over's layout is in [screens.md](screens.md).

## Deleting friend group data

The Privacy screen, opened from Settings, says "In a friend group, Dot Popper keeps your scores online so the group can see them." and, once this device has a token, holds "Delete my friend group data": a 2-second hold (Y on a controller) that sends `DELETE /player`, which leaves every group and deletes the player's scores on the server. "Your Stats stay." `Session#delete_everything`, then `#forget_identity`.

## Trying it without the server

`ruby script/group_stub.rb [port]` runs an in-memory stand-in for the whole API on `127.0.0.1` (port 9293 by default), seeded with a full group with a title history, joined by code 1234567. Run the game with `DOT_POPPER_SERVER=http://127.0.0.1:9293`. `DOT_POPPER_GROUP_SCREEN=1` opens the friend groups at launch, in a test build. The GUI galleries `test/gui/scenarios/screens_gallery.rb` and `redesign_gallery.rb` use it.

## Tests

`test/groups/session_test.rb`, `test/groups/jobs_test.rb`, `test/groups/outbox_test.rb`, `test/groups/read_model_test.rb`, `test/groups/group_file_test.rb`, `test/groups/group_stub_test.rb`, `test/server_exchanges_test.rb`, which replays the server's published exchanges through `Session`, `test/refresh_test.rb`, `test/network/link_test.rb`, `test/presentation/group_panel_test.rb`, `test/presentation/member_icon_test.rb`, `test/presentation/names_test.rb`, and `test/privacy/requests_test.rb`, which plays every request through a real `Session` and `Link` against a local server.
