---
status: accepted
date: 2026-11-05
deciders: coding agents, for the maintainer's review
---

# Steep checks the rules strictly against RBS signatures

## Context and Problem Statement

The rules in `lib/dot_popper/*.rb` decide every score and every second on the clock, and they are built from immutable `Data` values that the presentation and the shell read. A wrong type there, such as an integer radius leaking into a dot's position, plays on silently. Should the rules be type-checked, and how strictly?

## Decision Drivers

* The rules are the part of the game where a silent mistake would matter most (the record's only stated reason).
* A machine without the checker must still run the tests.
* A check that silently skips code is worse than none, because it is trusted.

## Considered Options

1. Steep, in its strict mode, against hand-written RBS signatures in `sig/`, with unsupported syntax an error, run by the default `rake` task after the tests.
2. No static type check: the unit tests and the fuzz test alone.

The record names no other option. Later research (2026-11-11), not a reason for the choice: Sorbet also checks Ruby statically, with its own signature syntax and a runtime layer; RBS's own `rbs test` checks signatures at run time during the tests, not statically; TypeProf infers signatures rather than checking hand-written ones. The record compares none of them with Steep.

## Decision Outcome

Chosen: option 1. When first run it found two real faults, an integer radius that could reach a dot's position through `Dot#confine`, and `Game#subscribe` with neither a listener nor a block failing late. Confidence: high that it catches what it checks; no recorded comparison says it is better than the alternatives above.

### Consequences

* Good, because a call Steep can't type fails the build rather than passing as untyped.
* Bad, because Steep 2.1 doesn't check `case`/`in`, so the typed rules branch with `if` and `is_a?` where pattern matching would read better; pattern matching stays in untyped code (the presentation, tests and scripts).
* Bad, because every class in the rules needs a hand-kept signature, and Steep's gems must be cached in `vendor/cache` for all three platforms.
* Neutral, because only `lib/dot_popper.rb` and `lib/dot_popper/*.rb` are checked: the presentation, the shell, and the subfolders (`continuity/`, `groups/`, `receipt/`, `privacy/`) are not, and a few signatures use `untyped` at the edges (`automation.rbs`, `build.rbs`, `entitlement.rbs`, `receipt.rbs`).

### Confirmation

`bundle exec rake` runs `test` then `steep` (the `Rakefile`); the `Steepfile` sets `Ruby.strict` and makes `UnsupportedSyntax` an error. `bundle exec rake test` runs without Steep. No CI workflow runs Steep: the Package workflow's test job runs `bundle exec rake test` only, so the check is enforced by the `bundle exec rake` that `AGENTS.md` requires before every push.

## More Information

How to run and extend the check is in [development](../design/development.md). Revisit pattern matching once Steep checks `case`/`in`.

Note (2026-11-12): the `Steepfile` also checks the use cases, `lib/dot_popper/use_cases/*.rb`, in the same strict mode, since [ADR-0017](0017-use-cases-hold-the-rules-that-need-two-areas.md). The Neutral consequence above describes the scope when this was decided.
