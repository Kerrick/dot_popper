---
status: accepted
date: 2026-11-13
deciders: the maintainer (Kerrick Long) for Clean Architecture, Domain-Driven Design and the game's three areas; coding agents for this layer
---

# Use cases hold the rules that need two of the game's areas

## Context and Problem Statement

The maintainer has decided that the game's code follows Clean Architecture and Domain-Driven Design, and that its domain divides into three areas: Gameplay and Metagame (playing, Stats, records, achievements, today's goal, friend groups and the title, themes), Monetization (Free and Pro, free games, locked features, the stores, receipts, license keys, proof that setdef is there), and Release Engineering. Asked whether that split is his decision: "It is."

Some of the game's rules need two areas at once. A Free player with no games left is offered Pro instead of a game; a new achievement is shown at Game Over only to Pro, though it is earned and kept by anyone; friend groups hear of the achievements a player earned while Free once Pro arrives. These rules lived in the `Show`, the presentation's object that ties the screens to the core, beside what each screen draws, and the one way into a game was a private method there that a press on `Cabinet`'s Home could bypass. Where do the rules that need two areas live?

## Decision Drivers

* The rules of play never know that Pro exists: `AGENTS.md` says "Pro never changes how the game plays or scores".
* Every way into a game spends exactly one free game ([ADR-0012](0012-free-games-20-then-3-a-day.md), [ADR-0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md)), and nothing else may start one.
* Rules are tested without a window (`AGENTS.md`), and the typed core stays typed ([ADR-0004](0004-steep-checks-the-rules-strictly.md)).
* What a player sees, hears, scores or pays does not change.

## Considered Options

1. Use cases: one object for each thing a player does that needs two areas (starting a game, finishing one, buying Pro), in `lib/dot_popper/use_cases/`, each given its collaborators when it is made. The screens call them, they call the areas, and an area that changes something another area cares about announces it.
2. Leave these rules in the `Show`, with the screens.
3. Put each rule in the area it mostly concerns, and tell that area about the other: `Cabinet` asks the free games before it starts a game, `Achievements` and the friend-group session ask `Entitlement` what to show and send.

## Decision Outcome

Chosen: option 1, because it alone keeps both areas ignorant of each other while giving each rule one home. Option 3 fails the first driver: `Cabinet` would know that games are counted for a purchase, and the achievements would know Pro. Option 2 keeps the rules out of both areas, but in an object that is also every screen's state, where the one door was a convention and the rules could only be tested through the screens. Confidence: medium. The use cases' tests and the existing presentation tests pass unchanged in what they check; no player has played a build with them.

### Consequences

* Good, because the one way into a game is a class (`UseCases::StartGame`), and `Cabinet` starts a game only when asked, never on a press, so a test can find every caller.
* Good, because each use case is tested alone, with memory stores and local fakes, and is checked by Steep with the core.
* Good, because Gameplay and Monetization meet only in a use case, or through an event one of them announces, so either can change without the other.
* Bad, because there is one more layer to follow from a press to a rule, and each use case needs an RBS signature, with interfaces for the collaborators the core does not type (the friend-group session, the store port).
* Bad, because, until they move too, two rules that need both areas are still asked of `Entitlement#pro?` inside a Metagame object, that only Pro uses a theme (`ThemeKeeper`) and joins or creates a friend group (`GroupPanel`), and what a screen shows a Free player (an achievement's day and progress) is still decided in the `Show`.
* Neutral, because an area told of another's event acts when it is told, on the game's thread, as it did before: nothing waits, and nothing happens later than it did.

### Confirmation

`test/use_cases/` tests each use case without a window. `test/use_cases/start_game_test.rb` fails if anything but `UseCases::StartGame` starts a game, in `lib/`, `script/`, `bin/`, `main.rb`, `conf.rb` or the Android kit. The `Steepfile` checks `lib/dot_popper/use_cases/*.rb`.

## More Information

Which use cases there are, what each takes and answers, and which events the areas announce are in [the architecture](../architecture.md#use-cases). The folders are not divided by area yet.
