---
status: accepted
date: 2026-11-05
deciders: the maintainer (Kerrick Long)
---

# A new dot offers a touch target within its first second

## Context and Problem Statement

The spec draws a new bright dot's place and velocity at random, under every popped dot. In the first iPad playtest a bright dot spawned almost wholly under a popped dot moving at nearly the same velocity, and stayed hidden until the clock ran out: nothing the player did could have saved that game. Should the rules stop a spawn that can't be tapped, and how narrowly?

## Decision Drivers

* A loss is worth enjoying only when the player can see it was their own (Juul, *The Art of Failure*).
* Luck the player can respond to is part of the game; luck that decides the outcome alone is not (Garfield, *Characteristics of Games*).
* Waiting for the bright dot to come out from under the others is the game, and must stay so.
* The maintainer's limit, as the record quotes him: "The rule change, if we do it, should only apply when velocity and position would cause there to be no HIG-compliant touch target within, say, 1 second."
* Seeded games and replays should play as before unless the rule acts.
* A spawn happens once per pop, so the check must be cheap.

## Considered Options

1. Check each draw: if the new dot would offer no 44-unit touch target, clear of every dot above it, at any 1/30 s step of its first second, draw the velocity again (up to four times), then the place and velocity (up to four more), and keep the last draw if all fail.
2. The spec's rule: every first draw stands.

## Decision Outcome

Chosen: option 1, because it removes the unfair loss the playtest found while acting only where the maintainer allowed. It uses no randomness unless it redraws, so most seeded games are unchanged. Confidence: high that it acts rarely and cheaply on ordinary screens. In `script/simulate.rb` (200 games a row), fewer than 1 spawn in 70 is redrawn on every screen but one; on a phone with fitted dots (R 30), about 1 in 20. Mean scores with and without it differ within the simulation's noise. `script/benchmark_spawn.rb` timed a spawn with 100 popped dots at 0.08 ms mean on a 27-inch monitor's field and 1.7 ms mean (6 ms at the 99th percentile) on a packed upright phone's.

### Consequences

* Good, because a dot that can't be tapped for a whole second, the unfair failure, is redrawn wherever a gap exists.
* Bad, because on a packed screen the rule does real work (70% of spawns redrawn with 100 popped dots on an upright phone), so a crowded field is somewhat kinder than the spec's.
* Bad, because the rules gain four classes (`Spawner`, `SpawnCheck`, `TouchTarget`, `Spawn`) that every change to movement or stacking must keep in step.
* Neutral, because when no gap exists at all the dot spawns as the spec would have it.

### Confirmation

`test/rules_fuzz_test.rb` checks after every spawn that the new dot offers a touch target within a second or used every try; `test/spawner_test.rb` and `test/touch_target_test.rb` test the parts. `Rules::SPAWN_TRIES` set to 0 restores the spec's rule, which `script/simulate.rb` uses for its comparison.

## More Information

The check's mechanics, sampling and numbers are in [the rules](../design/rules.md). The playtest is `doc/playtests/2026-11-05-ipad.md`.
