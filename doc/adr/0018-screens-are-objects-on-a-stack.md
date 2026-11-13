---
status: accepted
date: 2026-11-13
deciders: the maintainer (Kerrick Long) for Clean Architecture and Domain-Driven Design; coding agents for screens as objects on a stack, and this design
---

# Screens are objects on a stack, and the one on top answers every input

## Context and Problem Statement

The maintainer has decided that the game's code follows Clean Architecture and Domain-Driven Design ([ADR-0017](0017-use-cases-hold-the-rules-that-need-two-areas.md)). In the presentation, `Presentation::Show` was the state of every screen at once: a screen was not an object but a combination of a page symbol, flags for the offer of Pro, an achievement's dialog and the share preview, the friend groups' panel's own state and the game's. Which screen was on top was decided again in about fifteen if-chains, in different orders: what can be pressed, what Enter, Escape, Start and each gamepad button do, what a typed key does, what scrolls, which presses wait for their release, and what the renderer draws, some of them in `Shell::App` and `Shell::Renderer`. Adding a screen touched eight to ten places, and the chains disagreed in five corners a player could reach: a controller's Y did nothing on the offer over Game Over, the new-theme card let a controller and H act on Home under it, the offer let the list hidden under it scroll, several screens popped a dot of Home's under their veil, and an announcement of a title change could pass unseen. The goal set for this work was that each screen be an object that answers for itself, that one place say which is on top, and that adding a screen mean adding one object.

How do the presentation's screens hold their state and answer the player's input?

## Decision Drivers

* One place decides which screen is on top; every input, and the renderer, asks it.
* Each screen answers for itself what can be pressed and where, what each press does, its main and Back actions, each gamepad button, what scrolls and what a typed key does.
* Adding a screen is adding one object.
* Nothing a player sees, hears, presses, scores or pays changes, except where the chains disagreed, each case decided and recorded.
* No Lota outside the shell; the presentation's tests need no window ([ADR-0005](0005-gui-scenarios-play-the-real-game.md) keeps the GUI scenarios for the window).
* No work per frame beyond asking the screen on top: nothing is made each frame.
* The painters keep reading what they read through the `Show`, for now.

## Considered Options

1. **A stack of screen objects.** One object per screen (`Presentation::Screens`), made once with the `Show`. A screen opened over another is pushed on a stack over the screen for the game's state (Home, the Tutorial, a game, Game Over), and Back closes the top one. `Show#screen` is the top of the stack, or with none open the screen for the state; every input asks it, and the renderer draws the stack.
2. **Screen objects chosen from flags.** The same objects, with the `Show` keeping a flag for each and one if-chain in `Show#screen` choosing among them.
3. **Keep the flags and the chains**, and add tests that the chains agree.
4. **A graph of screens**, each naming the screens it may go to and from, as `Cabinet`'s states do for the game.

## Decision Outcome

Chosen: option 1, because it alone makes adding a screen one object: the screen opens itself over the one in view, and Back closes it, so no flag, no arm of a chain and no table of moves names it. Option 2 was the first step of this work, and kept a flag and an arm of `Show#screen` for every screen. Option 3 leaves every disagreement possible in a new chain, and adding a screen still touches every chain. Option 4 lists for each screen the screens under it, which the stack already knows, since every screen over Home or Game Over goes back to the one it was opened over. Confidence: medium. The tests that walk every screen at every size and play each input alone pass unchanged in what they check, and gallery screenshots taken before and after the renderer asked the stack match byte for byte where the galleries are repeatable; no player has played a build with it.

### Consequences

* Good, because each input is one call to the screen on top, so the chains can no longer disagree, and the five corners where they did now agree, each by what a player would expect (recorded in [screens](../design/screens.md#screens-as-objects)).
* Good, because a screen's state lives in its object (the dialog's achievement, the share preview's text, the offer's focus, Stats' hold and Undo, Credits' scroll), and the `Show` keeps what is not a screen: the game's feedback, the stack, and the use cases it makes.
* Good, because Back from Credits, Privacy or Change Server returns to Settings by closing the top of the stack, where a list of those screens did it before.
* Bad, because the screens reach into the `Show` for what they share (the layout, the words, the list's scroll, the effects), so the two know each other.
* Bad, because each screen is made once and reused, so a screen's state must be reset as it opens; a forgotten reset shows the last visit's state.
* Bad, because the `Show` keeps a one-line method for each value the painters and the tests read, until the painters take the screens' plans.
* Neutral, because the friend groups' pages are still the `GroupPanel`'s, inside one screen object, which tells the `Show` as it opens and closes.
* Neutral, because tests that read the code (the inputs test, the test that every game starts through `UseCases::StartGame`) read the screens' files too.

### Confirmation

`test/presentation/inputs_test.rb` fails if a control a screen answers (each screen's `#pressed`) or a screen object is reached by no input. `test/presentation/screen_plans_test.rb` walks every screen at every size. `themes_test.rb`, `games_test.rb`, `show_test.rb`, `achievements_test.rb` and `group_panel_test.rb` pin each corner where the chains disagreed. The GUI scenarios play the real game in a window.

## More Information

Which screens there are, what each answers, how the stack opens and closes them, and how to add one are in [screens](../design/screens.md#screens-as-objects); how each input reaches the screen on top is in [input](../design/input.md).

Notes (2026-11-13, after an independent review of this work):

* The outcome's reason, that option 1 "alone makes adding a screen one object", did not hold: a screen over Settings touched eight places, among them a list of Settings' screens in the `Show`, the keyword list of `Screens.made_for` and `Show` methods for its painter. That list is gone, the screens are made from one table (`Screens::ALL`), and a throwaway screen over Settings now touches its class, its line in that table and in the load list, the screen it opens from, its painter (with the shell's load list) and the renderer's choice of painter. Option 1 is still the one that does not name each screen in a chain or a flag; it is not one object. [screens](../design/screens.md#screens-as-objects) lists the places.
* The collection is now a stack in fact: a screen is pushed over the one on top, and only the top one is closed (an achievement's Get Pro closes its dialog before the offer opens). The `Show`'s questions of which screen is open (`#stats?`, `#settings?` and the rest) ask whether that screen is on top (`Show#on_top?`), where they asked a second question, the topmost screen over Home (`Show#page`), which is gone.
* State the `Show` kept for screens moved into them: each scrolling screen's list (`Screens::Scrolling`), the Tutorial's scene, the new-theme card's first moment. The friend groups' panel asks the stack whether its screens are open, where it kept a flag beside it.
* The Confirmation overstated what the inputs test checked: it read each screen's `#pressed` with a pattern that missed a one-line method, and its inputs only pressed at a place. Each screen now says which controls it answers (`#answers`), a press reaches only those, and the inputs test asks the screens and also presses a controller's buttons, the keyboard's keys and Android's Back. `test/presentation/screen_answers_test.rb` holds what every press does on every screen. Deleting each of the screens' methods in turn left 26 of 178 untested when this was decided, and 2 of 202 after (`Home#tile_note` and `Stats#plan`, values a painter reads).
* The driver "nothing is made each frame" was not true when this was decided and is not now: several screens build their plans and words on each call, as the `Show` did before. Nothing regressed; the sentence was wrong.
* The changes where the chains disagreed are named, with the books that decide each, in [screens](../design/screens.md#screens-as-objects), and an eighth joined them: an achievement's dialog no longer lets the grid under it scroll.
