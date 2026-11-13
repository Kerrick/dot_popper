---
status: accepted
date: 2026-11-08
deciders: the maintainer (Kerrick Long)
---

# Free games: your first 20, then 3 a day

## Context and Problem Statement

Pro is the one purchase. The brief had Free play unlimited, with Pro adding achievements, themes and friend groups. That gives a player who enjoys the game no reason tied to playing it to buy. How much may a Free player play?

## Decision Drivers

* The player should always know what they have and what comes next (Schell, *The Art of Game Design*), and state should be visible (Norman, *The Design of Everyday Things*), in plain words with one name for one thing (Johnson, *Designing with the Mind in Mind*).
* No dark patterns (`INSIPIRATION.md`): nothing hides the limit, nags, expires bought play, or sells a way around it.
* Apple 3.2.2(x): nothing may earn more games (no ratings, reviews or sharing); Apple 2.2: Free is never called a trial or a demo.
* A limit with no way past it is a dead end, so it applies only where Pro can be bought.

## Considered Options

1. Your first 20 games, which never refill, plus 3 games each local day, which don't carry over and are spent first; Pro makes games unlimited and keeps what was left.
2. Free games unlimited (the brief).

## Decision Outcome

Chosen: option 1, the maintainer's decision, replacing the brief. The record calls both numbers provisional. Confidence: low on the numbers, which no playtest has tested; high that the limit is visible and fair as built.

### Consequences

* Good, because Home's Play shows how many games are left, and with none left Play opens the Pro offer instead.
* Good, because the count is a save of its own (`games.txt`), outside what clearing Stats touches, so clearing can't refill it.
* Bad, because it trusts the player's clock and files, as the other saves do: a changed date or a deleted `games.txt` gives more games.
* Bad, because every way into a real game must spend one in one place (`UseCases::StartGame`), including the game that follows the tutorial or How to play; a gap there gives unlimited games.
* Neutral, because only a copy that offers a store is metered, and the bot and GUI scenarios are not, unless a scenario asks to be (`DOT_POPPER_FREE_GAMES`).

### Confirmation

`test/free_games_test.rb` tests the count, the day and the bank; `test/presentation/games_test.rb` checks that every way into a game spends one and that Play opens the offer with none left; `test/composition/root_test.rb` that a store build always meters. README.md and `doc/publishing.md` state the numbers and must change with `FreeGames::BANK` and `FreeGames::DAILY`.

## More Information

Where the count shows and how metering is decided are in [store and Pro](../design/store-and-pro.md).
