---
status: accepted
date: 2026-11-08
deciders: coding agents; the maintainer (Kerrick Long) owns the public policy and the store forms
---

# The privacy facts are generated from declarations the tests enforce

## Context and Problem Statement

The public privacy policy, Apple's privacy labels and manifest, and Google Play's Data safety form must say exactly what Dot Popper keeps and sends: every save file, every network request and its fields, every SDK and permission. The game keeps many save files and makes requests to setdef's server, three connectivity checks and the stores. A hand-written list in `doc/publishing.md` had to be kept current by whoever changed the code. How are the privacy facts kept true?

## Decision Drivers

* The facts must be accurate, and nobody can be trusted to keep a hand-written list current (the record's reason).
* One source for each fact, and everything else generated from it (Hunt and Thomas, *The Pragmatic Programmer*: DRY, applied to facts).
* What players read must be short and plain (Zinsser; Williams; Pinker's curse of knowledge).
* What no test here can check (the stores, the native hosts, the engine, the server) must be said plainly, not implied.

## Considered Options

1. Declarations in code (`lib/dot_popper/privacy`, `Groups::REQUESTS`) that are the only way to save a file or make a request, compared exactly with reality by tests, with `doc/privacy.json` generated from them (`bundle exec rake privacy`).
2. A hand-written list of facts and store answers in `doc/publishing.md`.

## Decision Outcome

Chosen: option 1, because a declaration that the code can't bypass, and a test that fails when reality and the declaration differ, keep the facts true without anyone remembering to. Confidence: high for what the tests can see; the document itself lists what they can't (`declared_but_not_enforced`).

### Consequences

* Good, because `Shell::SaveFile` refuses an undeclared name, every request is made only from its declaration (`Network::Job.of`), source scans forbid network calls outside `Network::Link` and file writes outside `SaveFile`, and a wire test plays every request against a local server.
* Good, because exact lists (shipped gems, Android dependencies and permissions, iOS usage strings, the privacy manifest's data types) fail `bundle exec rake` when something new appears, and Billing's version is pinned so a bump makes someone re-read its manifest.
* Bad, because every new save file, request or field takes a declaration, a label or reason for players, and a regenerated `doc/privacy.json` before the suite passes.
* Bad, because the server's own behavior (its logs and IP addresses) is outside the code, so the document defers to the server's policy there.

### Confirmation

`test/privacy/declared_test.rb` compares every list with the code and the build files and fails if `doc/privacy.json` is stale; `test/privacy/requests_test.rb` reads the wire. `AGENTS.md` makes declaring every saved file and request a rule.

## More Information

How the declarations, the document and its tests work is in [privacy](../design/privacy.md).

Note (2026-11-12): the requests are no longer declared in `Groups::REQUESTS` alone. Each part that makes requests declares its own as `REQUESTS` where it lives (`Privacy::PARTS`), and `Privacy::REQUESTS` merges them; `Network::Job.of` makes every request from its declaration, and `Network::Link` is the one place that reaches the network. The decision is unchanged.
