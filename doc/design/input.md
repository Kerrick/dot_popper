<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Input

How a press reaches Dot Popper, from a mouse, a finger, a gamepad or a keyboard: the one path every press takes, the gamepad cursor, each screen's gamepad buttons, dragging the Game Over pile, the worn-mouse filter, the words that follow the player's hand, and the keys. It is for anyone changing how the game hears the player. The player-facing table of controls is in [README.md](../../README.md), "How to play".

## One path for every press

Every press goes through one path, so every rule about presses holds for every kind of input without extra code.

1. `main.rb` hands each of Lota's callbacks to `Shell::App` (`mouse_pressed`, `touch_pressed`, `gamepad_pressed`, `gamepad_axis`, and their moves and releases).
2. `Presentation::InputRouter` decides which callbacks are presses, and turns each into a `Tap` (`x`, `y`, and the `InputKind` that made it).
3. `App#press` hands the `Tap` to `Show#tap` on the frame it happens, unless the Show waits for its release (Game Over, below).
4. `Show#tap` sends it to the game (`Cabinet#press`) during a game, or to the button under it (`Show#controls`, `Show#control_at`) anywhere else.

`InputRouter`'s rules:

- A mouse press counts for buttons 1, 2 and 3, when the button goes down.
- A finger counts when it goes down, and each finger is a press of its own. Only a `touchscreen` device counts: a trackpad's touches (0 to 1 coordinates) do not.
- SDL makes up a mouse press, marked `istouch`, for each finger. It is ignored, so one finger is one press.
- A gamepad's press is a click at the gamepad cursor (`InputRouter#gamepad_pressed`). Its release is at the cursor too, wherever it has moved.
- Moves and releases are sorted the same way, for dragging the pile and scrolling lists.

**Only a press at a place touches the score.** During a game, `Show#primary` does nothing, and Start, B, X, Y, the shoulders and Select do nothing. A button that scored without aiming would bypass the game. The one exception to "every press is heard on its frame" is the worn-mouse filter, which drops a press rather than delaying it.

A press during setdef's splash only skips the splash (`App#skip_splash`), and the game never hears it.

## Mouse

- Any of the three buttons presses.
- A motion counts as using the mouse only once the pointer has really travelled 8 units (`Presentation::MouseTravel::ENOUGH`), so a window opening or resizing under a still pointer does not take the words or hide the gamepad cursor. For 0.5 seconds after the window opens or changes size (`App::SETTLE`), motions do not count at all.
- Only the mouse hovers. A button under it brightens (`Show#hovered`, `Style::HOVER`), and the system pointer becomes the pointing hand (`App#point_the_mouse`). After a finger or gamepad press, nothing hovers. [screens.md](screens.md) has the hover's look.
- The wheel scrolls a list (`Show#wheel_scroll`, `Style::CREDITS.wheel` lines a notch).
- When the window loses focus, every held press is let go (`App#focus`): dragged dots, "Clear my stats…", and the hold to leave a friend group.

## Touch

- Each finger is a press of its own, with its touch id as its key.
- A finger dragged on a scrolling list scrolls it (`Show#drag_scroll`). A press on a list's row waits for its release, so a drag that starts on a row scrolls instead of opening it (`Show#press_list`).
- A finger press hides the gamepad cursor and starts the mouse's travel afresh, so only a new, deliberate mouse move takes the words back to the mouse.

## Gamepad

### Controllers

`Shell::Gamepads` keeps the controllers that Lota's `joystickadded` hands it, and forgets them on `joystickremoved`. It never asks Lota for the list of joysticks each frame. It keeps only joysticks that are gamepads, so an iPad's accelerometer, which SDL can present as a joystick, is never one. A controller paired with an iPad or a phone plays as it does on a computer.

When several gamepads are connected, their pushes add together (`Stick#+`, at most a full tilt each way). Unplugging a controller lets its trigger and A go.

`DOT_POPPER_FAKE_GAMEPAD=1` plays as if a gamepad were in hand: the words name its buttons, its cursor shows, and `DOT_POPPER_FAKE_DRAG`'s drag is made with the cursor and A.

### The cursor

A gamepad aims a free cursor (`Presentation::GamepadCursor`) and A presses where it points. Its numbers are `Style::GAMEPAD` (`Presentation::GamepadStyle`).

| Setting | Value | What it does |
| --- | --- | --- |
| `dead_zone` | 0.2 | A push inside this circle is a stick at rest, so a worn stick does not drift |
| `curve` | 2.0 | Past the dead zone, the cursor's speed is the push to this power: half a tilt moves at a quarter of the top speed, for fine aiming |
| `crossing` | 1.0 s | At full tilt, the cursor crosses the window's diagonal in this time, whatever the window's size, ramp included |
| `speed` | 16 R/s | The least top speed, in dot radii a second, so a small window keeps its feel |
| `ramp` | 0.08 s | The cursor gathers its speed over this time |

- **Speed follows the window.** `GamepadCursor#top_speed` is the window's diagonal divided by `crossing` less half the `ramp`, and never less than `speed` radii a second. A speed fixed in radii felt far too slow in a large window.
- **The ramp.** The cursor's pace may rise by at most 1/`ramp` of the top speed each second, and only up to what the push asks for. So a gentle push is at its speed almost at once, a full tilt takes 0.08 seconds to reach full speed, and letting go stops the cursor dead. Swink's *Game Feel* puts "feels direct" below about 100 ms, which is why the ramp is that short.
- **The d-pad** pushes the cursor as the left stick does (`Stick.dpad`), through the same shaping, with no other smoothing. A diagonal moves no faster than a straight direction, since the push is capped at a full tilt.
- **Read every frame.** The left stick and d-pad are read each frame (`Gamepads#stick`, from `App#update`), not from axis-change events, so a change of window focus cannot leave the cursor stuck moving.
- **On the Credits screen** the left stick and d-pad scroll the text instead, and the cursor stays where it is (`App#read_with_stick`).
- **It stays in the window** (`GamepadCursor#at`), and refits when the window changes size (`#refit`).

### There is no aim assist

The cursor goes only where the stick sends it, and never drifts toward a dot. A cursor pulled toward the bright dot would choose which dot a press reaches, which is the player's choice, and one pulled toward any dot would make mistakes the player never aimed.

### When the cursor shows

- Any gamepad button, the right or left trigger, or a push past the dead zone shows the cursor (`App#gamepad_used`, `GamepadCursor#update`).
- A mouse press, a deliberate mouse move, or a finger hides it. While hidden it waits where the mouse is, so a player who picks up the controller starts from there.
- A press of A while the cursor is hidden still presses where it waits. Making the first press only reveal the cursor would mean the game ignored a press.

### How the cursor is drawn

`Shell::CursorPainter` draws a reticle over everything: a thin cream ring of radius 0.3 R (`ring`), four ticks from 0.42 R to 0.6 R (`ticks`), and a pip of 4 device pixels at the centre (`pip`), with a stroke of 0.04 R (`line`), at least one device pixel. Each part sits on a dark edge two pixels wider (the palette's shadow at 0.75), so it shows on a light dot or the night. It is open in the middle, so it never hides the dot it is over. Its centre and strokes sit on whole device pixels, while the press lands where the cursor really is.

### The triggers

The right trigger is a second A (`Presentation::Trigger`). It presses once when pulled to 0.5 (`trigger_press`) and can press again only after it is let back below 0.3 (`trigger_release`), so a trigger resting near the line cannot press twice. Holding A and the right trigger together is one press (`App#gamepad_down`, `@pad_held`), which ends when both are let go.

The left trigger, with the same thresholds, opens Friend groups from Home (LT).

### The buttons on each screen

`Presentation::GamepadButtons` maps LÖVE's names for an Xbox pad's buttons to intents. SDL maps every other gamepad to those names, so a PlayStation pad's cross is `:a`.

| Button | Intent | What it does |
| --- | --- | --- |
| A | `:press` | A press at the cursor. Aimed at no button, it presses the screen's main button (`Show#primary`) |
| Start | `:start` | The screen's main button (`Show#start`), except on a friend group, where holding it leaves the group |
| B | `:leave` | Back, Close or Home (`Show#back`); on Home, Quit, asked twice |
| View, Back, Select or Share (`GamepadButtons::SETTINGS`, LÖVE's `:back`) | `:select` | Settings on Home; Sound in Settings |
| X, Y, LB, RB | `:x`, `:y`, `:lb`, `:rb` | Each screen's own buttons, labelled on it (`Show#pad`) |

The d-pad has no intent of its own: it moves the cursor. The right stick scrolls a list (`Show#stick_scroll`, `Style::CREDITS.stick` lines a second at full tilt) and, on Game Over, rolls the pile ([look-and-sound.md](look-and-sound.md)).

Each screen's own buttons (`Show#pad`, `#pad_game_over`, `#pad_dialog`, `#pad_offer`, `#pad_groups`, `GroupPanel#pad`):

| Screen | Buttons |
| --- | --- |
| Home | A or Start: Play. X: Stats. Y: How to play. LB: Achievements. RB: Themes. LT: Friend groups. Select: Settings. B: "Press B again to quit", and a second B within 2 seconds (`Show::QUIT_ASK`) quits, except on iOS, where B does nothing |
| Game Over | A at no button, or Start: Play again, once the grace is over. B: Home. Y: Share my score. LB: the new achievement, and RB: the friend group whose title the game took, when Game Over shows that line |
| Share preview | A at no button, or Y: Copy. B: Close |
| Stats | B or Start: Back. Y: Undo while it is offered, or else hold to clear the stats |
| Achievements | X: the first achievement's dialog. In the dialog, LB and RB: the previous or next achievement; B: Close |
| Themes | LB and RB: use the previous or next theme. B: Back |
| Settings | Select: Sound. LB: Dot size, where it is offered. RB: Display, on a computer. X: Credits and licenses. Y: Privacy. B: Back |
| Privacy | X: Read the privacy policy. Y: hold to delete my friend group data. B: Back |
| Credits | Left stick, d-pad or right stick: scroll. B: Back |
| Pro offer | A at no button: Buy. X: Paste license key where the copy takes license keys, or else Restore Purchases. B: Back |
| Tutorial | B: Skip |
| A new theme's notice | A at no button: Use. B: Not now |
| Friend groups | See [friend-groups.md](friend-groups.md). B is Back on every one of them |
| A game | Only A and the right trigger, at the cursor |

Where a gamepad was used last, each button's label names its button, as "Play (A)", "Settings (Select)" or "Hold Y to clear my stats…" (`ByInput`, below), and Home's large buttons carry badges: X, LB, RB and LT (`buttons.badge_*` in `Style::WORDS`). Home shows "Play (A)" only, though Start plays too. In the Themes screen and the achievement dialog, the LB and RB steps are drawn only for a gamepad.

## Dragging the Game Over pile

On Game Over, the pile of the game's dots can be picked up, dragged and thrown. Schell's Lens of the Toy: reaching out to grab a dot is the first thing a player tries, and most players have only a finger or a mouse. `Presentation::PileGrabs` decides what each press is without Lota, and `Shell::Dragging` carries it out on `Shell::Pile`. The pile's look and its tilting are in [look-and-sound.md](look-and-sound.md).

**Which presses wait.** `Show#waits_for_release?` is true on Game Over, away from its buttons, with no share preview or offer open. Such a press goes to `Dragging#press` instead of `Show#tap`. A press on one of Game Over's buttons, and every press anywhere else, counts the moment it goes down.

**A press becomes a drag** once it wanders more than a quarter of a radius from where it went down (`slop`), or stays down on a dot for 0.15 seconds (`hold`). A press that never wanders and lets go sooner is a click.

**A held dot** closes on the pointer in about 0.05 seconds (`follow`), never faster than 60 radii a second (`fastest`), pushing the others aside. Each frame, `Dragging#update` gives it the velocity that closes the gap (`Grab#pull`, `Pile#steer`). Lota binds `MouseJoint.new` but none of its setters, so a joint cannot follow a pointer. Box2D's contacts and walls still stop the dot, and a held dot is a Box2D bullet, so it cannot pass through a wall. Dragging closes the pile's lid, as tilting does.

**Letting go** throws the dot at the pointer's speed over its last tenth of a second (`window`), at most 40 radii a second (`fling`).

**A click** that drags nothing is heard as the press it would have been, but only as it is let go (`Click`, then `Show#tap`). A mouse's or finger's click away from the buttons does nothing on Game Over; a gamepad's presses Play again, as A aimed at no button does everywhere. A click made during Game Over's grace (`Rules::GAME_OVER_GRACE`, 0.9 seconds) is ignored when it lets go, exactly as it would have been on press. No click counts while another pointer is dragging, so a drag never leaves Game Over. A swipe that starts off the pile does nothing.

**Several pointers.** Each finger holds a dot of its own, keyed by its touch id, and a dot already held cannot be taken by another. The mouse's key is `:mouse`, a gamepad's `:gamepad`.

**Grabs are dropped**, each held dot keeping the speed it has, when a key is pressed again before it was let go (iOS can cancel a touch without saying so), when the window loses focus, and when a game starts, Home shows, or the game ends (`Dragging#call`).

| `Style::GRAB` | Usual | Calm (`CALM_GRAB`, `DOT_POPPER_CALM=1`) |
| --- | --- | --- |
| `slop` | 0.25 R | 0.25 R |
| `hold` | 0.15 s | 0.15 s |
| `follow` | 0.05 s | 0.12 s |
| `fastest` | 60 R/s | 20 R/s |
| `fling` | 40 R/s | 6 R/s |
| `window` | 0.1 s | 0.1 s |

### A gamepad's A drags as a mouse button does

A, or the right trigger, is a pointer at the cursor, under the key `:gamepad`. Each frame while it is held, `App#update` moves that pointer to the cursor (`Dragging#move(:gamepad, ...)`). Holding A on a dot for 0.15 seconds, or moving the cursor past the slop, picks the dot up. It follows the cursor at the same pace as a mouse, and letting go throws it at the cursor's speed. Start still goes on at once. `Lota.gamepadreleased` in `main.rb` reports the release (`App#gamepad_released`, `#gamepad_up`).

## A worn mouse's double click is dropped

A worn mouse's switch can send one click as two, a few hundredths of a second apart. The second lands on the popped dot the first left behind, a mistake that costs 2 points and 2 seconds. A loss has to feel like the player's own (Juul, *The Art of Failure*), and a switch's chatter is not. So `Presentation::Chatter` drops a press of a mouse button that comes less than 0.06 seconds after that button's last press and within 8 units of it, and drops its release too, so a drag on the pile never sees a stray one. Its numbers are `Style::CHATTER` (`ChatterStyle`: `seconds: 0.06`, `reach: 8.0`).

- A switch's bounce is under 0.02 seconds, and a failing switch chatters at 0.05 to 0.08. A hand clicking twice as fast as it can takes 0.1 seconds or more. 8 units is `MouseTravel`'s line between a jitter and a nudge.
- Each press is timed from its button's last press, dropped or not, so a run of chatter is dropped whole.
- A press is never held back. It is heard on its frame, or dropped. It is dropped whatever it would hit, on every screen, the splash included, so the rule never depends on whether the press would have been a mistake. The maintainer approved this as a narrow exception.
- Only the mouse is filtered (`App#chattered?`, `#released_chatter?`). Several fingers can land together on purpose, and a gamepad's buttons do not chatter this way.
- Its clock is the frames' unclamped time (`App`'s `@uptime`), so the GUI scenarios, whose frames are a sixtieth of a second of game time, play as they would.
- When the window loses focus, no release is waited for (`Chatter#let_go`).
- The bot (`DOT_POPPER_AUTOPLAY`) and the fake drag never come through the mouse, so they are untouched.

## The words follow the last input

The words that say what to do follow the input the player used last. `Show#input=` takes an `InputKind` (`TOUCH`, `MOUSE` or `GAMEPAD`) from each `Tap` that `InputRouter` makes (`App#heard`), from each gamepad button or trigger, and from each stick push past the dead zone. A phone or tablet starts with touch and a computer with the mouse (`InputKind.starting`). An instruction names what the player is doing with their hands.

- Each phrase that varies is a `Presentation::ByInput`, with a `touch`, `mouse` and `gamepad` text. `Words#for(kind)` gives the words for one input, so painters read `words.play` and get the right one. A button's label inside `Style::WORDS.buttons` is read with `Words#button`.
- Touch and mouse read alike. A gamepad's text names the button in parentheses: "Play (A)", "Back (B)", "Share my score (Y)", "Settings (Select)", "Dot size (LB)", "Display (RB)". Held buttons say so: "Hold Y to clear my stats…", "Hold Y to leave every friend group and delete your scores online."
- Friend groups' labels add the button the same way (`GroupPanel#pressed_by`; [friend-groups.md](friend-groups.md)).
- How to play does not depend on reading English ([ADR-0003](../adr/0003-how-to-play-is-taught-without-words.md)). The tutorial's guide is drawn as the hand in use: a pointing hand, a mouse pointer, or the gamepad's reticle with an A (`Shell::GhostPainter`; [tutorial.md](tutorial.md)).

## Keyboard

`App#key_pressed`, in order. The first that applies wins.

| Key | What it does |
| --- | --- |
| Any key during the splash | Skips the splash |
| Ctrl+V or Cmd+V | Pastes, where a screen takes a paste (`Show#paste_shortcut`) |
| Digits, Backspace, Delete | On the keypad that joins a friend group: a digit, or the last one away (`GroupPanel#type`) |
| Letters, digits, hyphen, Backspace, Enter | On a computer's Pro offer that takes license keys: the key being typed (`WebsiteStore#type`) |
| M | Sound off or on (`Speaker#toggle_mute`) |
| H | How to play, from Home |
| C | Credits and licenses, from Settings |
| Up, Down, Page Up, Page Down, Home, End | Scroll a list (`Show#scroll_key`). Only while a list scrolls do held keys repeat (`App#repeat_keys`) |
| Enter, Space | The screen's main button (`Show#primary`), on any device. Nothing during a game |
| Escape | Back, Close or Home where there is one (`Show#back`). Otherwise, on a computer it quits, during a game too; on Android's Home it leaves the app; on iOS it does nothing |
| F11, Alt+Enter (Cmd+Enter on a Mac) | Switches fullscreen (`DesktopWindow#toggle_fullscreen`), on a computer only |

Android's Back arrives as Escape ([platforms.md](platforms.md)). A phone's or tablet's keyboard never quits the app or leaves fullscreen.

## Where it is tested

| Test | What it checks |
| --- | --- |
| `test/presentation/input_router_test.rb` | Which callbacks are presses, and their `InputKind` |
| `test/presentation/gamepad_cursor_test.rb` | The dead zone, curve, speed, ramp, d-pad and showing |
| `test/presentation/gamepad_buttons_test.rb` | The button map, Select on Home and in Settings, Start and B on Home, the trigger's thresholds |
| `test/shell/gamepads_test.rb` | Which joysticks are kept, and their pushes added |
| `test/presentation/pile_grab_test.rb` | Drags, clicks, throws and drops |
| `test/presentation/chatter_test.rb` | Which presses and releases are dropped |
| `test/presentation/mouse_travel_test.rb` | A deliberate move against a jitter |
| `test/presentation/words_test.rb`, `show_test.rb` | The words for each input, and presses on each screen |
| GUI scenarios `pile`, `pile_gamepad`, `words`, `hover` (`test/gui/scenarios/`) | The real game: a mouse drag and throw, a gamepad drag and A's click, the words and the hand following the input, the hover |

[development.md](development.md) has how the GUI scenarios run.
