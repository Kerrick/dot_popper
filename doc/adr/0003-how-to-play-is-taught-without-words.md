---
status: accepted
date: 2026-11-09
deciders: the maintainer (Kerrick Long)
---

# How to play is taught without words, as the opening of the first game

## Context and Problem Statement

Dot Popper has two rules a new player must learn: a bright dot pays a point and a second, and a new dot appears under the popped ones, so a tap on a popped dot is a mistake that costs two of each. In playtests one player ignored the words on the title and asked how to play, and another never noticed that a pop adds a second. The maintainer's goal, as the record quotes him, is that "a person who can't read English should understand and enjoy it". How does the game teach its rules?

## Decision Drivers

* How to play must never depend on reading English (a rule in `AGENTS.md`).
* Players don't read during intense action (Johnson, *Designing with the Mind in Mind*; Hodent, *The Gamer's Brain*), and a penalty is the wrong moment to ask them to (Saffer, *Microinteractions*).
* A demonstration must show what the game really does (Hodent); players learn the pattern they see (Koster, *A Theory of Fun*).
* Recognising something already seen is easier than recalling it (Johnson), and symbols such as ✕ or ✓ are not universal (Westland and Maggio).
* A first game should start at once; a lesson must be short and skippable.

## Considered Options

1. A wordless tutorial that is the opening of the first game, before its clock runs, using the real dots, HUD and feedback; the game goes on from the state it leaves; wordless signs elsewhere (Home's legend as the tutorial's own numbers and stopwatch; Game Over replaying a mistake on the pile).
2. Sentences: Home's legend in words, a hint under the score on the first mistake, two sentences on Game Over about stacking, and a line about dragging the pile.
3. A wordless tutorial as a separate scene that ends by resetting to a fresh game at 0 points and 10 seconds.

## Decision Outcome

Chosen: option 1. Option 2 depends on reading and covered the field mid-game. Option 3 taught something that never happens: the maintainer saw its dots vanish and the HUD drop from 2 and 12 to 0 and 10. He then confirmed option 1 in the record's words: "The tutorial _is_ the game; the game should be in whatever state the tutorial forces the player through." Confidence: medium. Each part follows a playtest or the maintainer's review, but how well players with no English learn from it has not been measured.

### Consequences

* Good, because the lesson works muted and unread, and every sign it uses is one the player sees again in play.
* Good, because the first game keeps the tutorial's dots, score, time and dots in a row, so nothing is unlearned. (That a Skip starts a clean game is superseded by [ADR-0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md): the same game plays on.)
* Bad, because the tutorial is the most tuned part of the presentation (beats, timings, the guide's hand), and every change to the game's feedback must be checked in it too.
* Bad, because a demonstrated mistake shows its cost but must never charge the learner. (That this makes the tutorial's rules differ from a game's is superseded by [ADR-0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md): the learner's press never reaches the game.)
* Neutral, because a game after the tutorial, or after How to play, spends a free game like any other ([ADR-0012](0012-free-games-20-then-3-a-day.md)).

### Confirmation

`test/presentation/tutorial_test.rb`, `show_tutorial_test.rb` and `tutor_test.rb` test the beats, the handover and Game Over's replay; the GUI scenarios `tutorial.rb`, `tutorial_skip.rb` and `how_to_play.rb` play them in a window. Reviews of any screen check that how to play needs no English.

## More Information

How the tutorial runs, beat by beat, and the wordless signs are in [the tutorial](../design/tutorial.md). [ADR-0016](0016-the-tutorial-is-a-layer-over-a-paused-game.md) makes the tutorial a layer over the first game, paused, and Skip take that layer away.
