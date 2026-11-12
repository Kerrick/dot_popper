---
status: accepted
date: 2026-11-12
deciders: the maintainer (Kerrick Long) for the decision; coding agents for its design
---

# The tutorial is a layer over the first game, paused, and Skip takes the layer away

## Context and Problem Statement

The tutorial ([ADR-0003](0003-how-to-play-is-taught-without-words.md)) kept a copy of the first game of its own: its dots, its score, its seconds and its row, with the rules' sums for a pop and a penalty written again in the presentation. `Cabinet` stayed on Home meanwhile, and at the tutorial's end the copy's values were passed to a new `Game`. Every rule and every listener had to agree with that copy, and not all did: the achievement watch counted the row one behind in the game that followed. A Skip threw the copy away and started a fresh game at 0 points and 10 seconds. The maintainer, on seeing it:

> "Keeping a second copy of the game is an implementation detail I didn't pay attention to, and a likely source of many bugs I've reported. I'd rather it simply... be a game. That gets paused to show tutorial-style animations etc."

> "Skip should skip all the tutorial-y bits being added to the current game, and get out of the way so the player can play."

How does the tutorial play on the game itself, and what does Skip do?

## Decision Drivers

* The maintainer's two requirements above: one game, paused and drawn over; Skip removes the tutorial's parts and the same game plays on.
* What a player sees and hears in the tutorial stays as it was, beat for beat: it is the most tuned part of the presentation (ADR-0003).
* A learner's tap on a popped dot never costs anything (ADR-0003).
* The guide's demonstrated mistake is not the player's, so Stats and achievements leave it out.
* Every free game is spent in one place ([ADR-0012](0012-free-games-20-then-3-a-day.md)).

## Considered Options

1. A layer over a paused game: `Cabinet` holds the one game in a `Paused` state from the tutorial's first frame; the tutorial moves its dots at its own pace, passes it only the presses it chooses, and draws it through a view that runs behind the rules; at its end, or at Skip, the game is unpaused as it is.
2. The same layer, with a Skip that abandons the paused game and starts a fresh one, as Play does.
3. A scripted copy of the game, handed over by copying its values into a new game at the end, and a Skip that starts a fresh game (what the tutorial was).

## Decision Outcome

Chosen: option 1, because it alone meets both of the maintainer's requirements. Option 3 is the second copy he named as a source of bugs. Option 2 has one game, but its Skip starts and ends games rather than getting out of the way. Confidence: medium. Tests pin each beat of the tutorial frame by frame on three screens, and nothing in them changed; how players take the new Skip has not been seen.

### Consequences

* Good, because there is one game, whose rules alone decide its score, clock and row: a pop's payoff and the penalty come from the rules' events, nothing is copied as play begins, and the achievement watch's row agrees with the game's.
* Good, because a learner's tap on a popped dot costs nothing by never reaching the game, so the tutorial's rules are a game's rules.
* Good, because Skip keeps what the player did: their pops, and any cost the guide's mistake already took, carry on into play.
* Bad, because the tutorial still changes the game in two ways its rules do not: it places the first two bright dots and, on a narrow screen, turns the first upward, so the parting reads the same on every screen. Only a paused game may be arranged (`Cabinet#arrange`).
* Bad, because the tutorial draws the game behind the rules, a popped dot still bright and a spawned one unborn until it shows them, so anything that draws during the tutorial must draw its view (`Tutorial#dots`), and Skip must first show what it held back.
* Bad, because the game is spent when the tutorial opens: a player who leaves during the tutorial has spent a game, and with none left How to play opens the offer of Pro, as Play does.
* Neutral, because the game's listeners hear nothing while it is paused, and `GameStarted` is announced as play begins, so Stats count the tutorial's pops as pops with no wait, and never the guide's mistake.
* Neutral, because a game the tutorial played over draws its dots from its seed from the third on, so a session started with a set seed plays other dots than before.

### Confirmation

`test/cabinet_test.rb` tests the paused game; `test/presentation/tutorial_beats_test.rb` pins the tutorial's beats, numbers, sounds, flights, spotlight, guide and dots frame by frame; `tutorial_test.rb` and `show_tutorial_test.rb` test that presses on popped dots never reach the game, that play begins on the same game, and Skip at several beats; `games_test.rb` that the one spend is at the tutorial's opening; the GUI scenarios `tutorial.rb`, `tutorial_skip.rb` and `how_to_play.rb` play them in a window.

## More Information

This supersedes the parts of ADR-0003 that have a Skip start a clean game and the tutorial's rules differ from a game's; ADR-0003's decision to teach without words, as the opening of the first game, stands. When the free game is spent follows from the tutorial's game being a game from its first frame. How the tutorial plays over the paused game is in [the tutorial](../design/tutorial.md).
