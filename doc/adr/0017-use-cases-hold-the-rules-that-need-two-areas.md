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
* Bad, because each such rule has a use case of its own, some only a few lines long (whether Join and Create lead to the offer is one test of `Entitlement#pro?`), and a screen must ask the use case rather than `Entitlement` even for that. The `Show` still asks `Entitlement#pro?` for the offer of Pro itself, which is Monetization's alone.
* Neutral, because an area told of another's event acts when it is told, on the game's thread, as it did before: nothing waits, and nothing happens later than it did.

### Confirmation

`test/use_cases/` tests each use case without a window. `test/use_cases/start_game_test.rb` fails if any line outside `UseCases::StartGame`, in `lib/`, `script/`, `bin/`, `main.rb`, `conf.rb` or the Android kit, calls `Cabinet#start_game` or `#start_paused` or names either as a Symbol; it reads the source, so a name built at run time would pass it. `test/use_cases/pro_knowledge_test.rb` fails if any file in `lib/` names Pro (`pro?` or `Entitlement`) beyond Monetization's own code, the use cases, the `Show`'s offer and the composition root. The `Steepfile` checks `lib/dot_popper/use_cases/*.rb`.

## More Information

Which use cases there are, what each takes and answers, and which events the areas announce are in [the architecture](../architecture.md#use-cases). The folders are not divided by area yet.

Notes (2026-11-12):

* Option 1 named the three use cases weighed when this was decided. Three more follow the same pattern: `UseTheme`, `JoinFriendGroup` and `ViewAchievements`. The architecture lists all six.
* Not every existing presentation test passed unchanged in what it checks, as the outcome says. `test/presentation/games_test.rb`'s one-door test was narrowed in the same change: it no longer scans `shell/` or `tutorial.rb`, or how the `Show` opens the tutorial, and now counts the `Show`'s calls to `StartGame`. `test/use_cases/start_game_test.rb` scans `shell/` and `tutorial.rb` instead.

Notes (2026-11-13):

* The composition root makes the use cases and subscribes them (`Composition.use_cases`); the `Show` no longer makes them. The `Show` and its screens are no longer given `Entitlement`, the store or the free games: the offer of Pro asks `BuyPro` for everything it shows, so the Consequence that the `Show` still asks `Entitlement#pro?` for the offer no longer holds. `test/use_cases/pro_knowledge_test.rb` no longer exempts the `Show` or any screen: it walks the game as the root builds it and fails if the presentation holds what decides Pro, and its scan of the names is a second line.
* `JoinFriendGroup` is `JoinOrCreateFriendGroup`, since it creates groups too, and the friend groups' panel acts on its answers rather than asking whether it is locked.
* `FinishGame` hears the rules' events itself, and `GameEnded` says whether the tutorial opened the game, so nothing it finishes with comes from the screens.
* The small use cases were kept rather than folded into one Monetization question of what Pro unlocks: each still owns an answer the screens act on (what Join, Create and a chosen theme lead to, which theme is current, what an achievement shows), where one question would leave each screen to decide what a locked answer means.
* The one way into a game no longer rests on the scan alone: `Cabinet#start_game` and `#start_paused` are private, and a cabinet hands out its one `Cabinet::Starts` once, which the composition root gives `StartGame`. The scan named in the Confirmation is a second line, and also finds the Starts taken elsewhere.
* `test/presentation/games_test.rb` no longer counts the `Show`'s calls to `StartGame`, as the earlier note says: it gives a `Show` a door into a game that never opens, and checks that every way in asks it once and starts nothing.
* No constructor subscribes a listener: the composition root subscribes the `Show` to `Cabinet` after `FinishGame`, as it subscribes the use cases.

Notes (2026-11-13, later), correcting the notes above where they said more than the code did:

* Nothing in the core, the use cases, the presentation or the composition root subscribes itself. The shell's `Shell::DevelopmentHooks` does, as it is made, when a development setting asks it to meter frames; `Shell::App#load` subscribes the shell's own listeners.
* The friend groups' panel asked `JoinOrCreateFriendGroup#choose` before every Join and Create, so the `:offer` that `#join` and `#create` answer never arrived. It now asks `#start` (the old `#choose`) only where something comes before the request, the code pad or the friend groups' notice, and otherwise acts on what `#join` and `#create` answer. Whether the player has Pro is private to each use case that asks it (`#locked?`, `BuyPro#owned?`), except `UseTheme#locked?`, which the new-theme card still asks.
* What an achievement's dialog shows is `ViewAchievements#status` (`:earned`, `:not_earned`, or `:offer` for a Free player), and the offer thanks the player when `BuyPro#status` answers `:thanks`.
* Game Over no longer reads `FinishGame`'s last result, which was right only because the composition root subscribed `FinishGame` to the rules before the `Show`: `FinishGame` tells the `Show` each game as it finishes it.
* `Cabinet` has no method of its own that starts a game, private or not: only its `Cabinet::Starts` can. Nothing else is handed the means to start one, but Ruby cannot forbid reflection, and reading `StartGame`'s Starts by reflection still starts a game; the scan in the Confirmation is now for the Starts taken or read (`@starts`), and a name spelled at run time passes it.
