---
status: accepted
date: 2026-11-13
deciders: the maintainer (Kerrick Long)
---

# The code follows Clean Architecture and Domain-Driven Design, with the domain in three areas

## Context and Problem Statement

Dot Popper's code was in three layers: the rules, the presentation, and the shell that calls Lota. That kept Lota out of the rules, but it left three things undecided. The domain was one undivided body, so the rules of play, the rules of Pro and the code that builds a release were told apart only by file name. Rules that belong to no screen lived in the presentation's largest object. And the same thing had different words in the code, on screen and on the server.

Two proposals for restructuring the code were written in November 2026, one from the code alone and one in a workshop with the maintainer, following Lilienthal and Schwentner's *Domain-Driven Transformation*. They agreed on much and differed on how the domain divides. What is the code's architecture, and how is its domain divided?

## Decision Drivers

* The maintainer's rule that Pro never changes how the game plays or scores (`AGENTS.md`).
* His rule that code, screens, documents and the server use the same word for the same thing (`GLOSSARY.md`).
* Every outside party is tested the same way, with local fakes. The maintainer, on not having chosen a payment company, as that record quotes him: "Why do I have to know to be able to test it? Feathers, Beck, Fowler, Martin, Freeman & Pryce, and others have written about this before." ([ADR-0009](0009-the-store-is-a-port.md))
* A framework is not part of the domain. The maintainer, on a proposal to count Lota as a bounded context: "Would Eric Evans ever say that Java SpringBoot is a ... context?"
* Tests are fast and need no window (`AGENTS.md`).

## Considered Options

1. Clean Architecture (Martin) and Domain-Driven Design (Evans), with the domain in three areas the maintainer chose in the workshop: Gameplay and Metagame, Monetization, and Release Engineering. Dependencies point inward to the rules, every outside party is behind a port, and each area's rules use that area's words.
2. The same two disciplines, with the game as one area and the server as another, divided inside into six parts that follow the code's modules, and the layers at the top of the folders (the proposal written from the code).
3. The three layers as they were, with the domain undivided.

## Decision Outcome

Chosen: option 1, the maintainer's decision. Asked whether this record may state his decision to adopt Clean Architecture and Domain-Driven Design with the three areas: "Yes." Asked earlier whether the split into the three areas is his decision: "It is." Asked whether class names that are metaphors should be renamed to plain terms: "Yes, follow domain-driven design and the ubiquitous languages of our domains wherever possible".

The areas came from his answers in the workshop, not from the code. He rejected separate areas for license keys, the friend-group server, theme releases, saving, Lota and the privacy facts, as parts of the two areas they serve or as no area at all, and named the third himself, of builds: "It's the domain of signing, attestation, downloads, updates, installers, etc."

The record holds no comparison in his words of option 1 with options 2 and 3, and no reason beyond the drivers above. A comparison of the two proposals by a coding agent preferred the three areas because the person who knows the domain chose them, where the six parts follow how the code happened to be filed. That is the agent's reasoning, not a recorded reason of his. Confidence: high that the decision is in force; medium that the code meets it, since the areas are kept apart by tests and use cases while the folders are still divided by layer.

### Consequences

* Good, because the rules of play never name Pro, so either area can change without the other, and a rule that needs both has one home ([ADR-0017](0017-use-cases-hold-the-rules-that-need-two-areas.md)).
* Good, because the rules, the use cases, the presentation and the composition root are tested without a window, a store or a network.
* Good, because one word for one thing is checked (`test/glossary_test.rb`), and a class is named in its area's words.
* Bad, because the game has more layers and more small objects than its size alone would ask for: use cases, a composition root, a port and a fake for each outside party.
* Bad, because the areas are not yet folders. Until they are, what keeps them apart is a test that reads the code and the discipline of whoever changes it, and some of each area's rules still live in the presentation.
* Bad, because every structural change must be weighed against two books' vocabularies as well as the game's own.
* Neutral, because Lota and the server's framework are details in an outer layer, not areas.

### Confirmation

`test/use_cases/pro_knowledge_test.rb` fails if code outside Monetization, the use cases and the composition root knows of Pro. `test/shell/platforms_test.rb` fails if anything but the shell names a system, and `test/composition/root_test.rb` if the composition root names Lota or the shell; the tests of the rules, the use cases and the presentation run where Lota is not loaded, so a call to it that a test reaches fails. `test/glossary_test.rb` fails on a word the glossary says not to use. Steep checks the rules and the use cases ([ADR-0004](0004-steep-checks-the-rules-strictly.md)). A change to the architecture is reviewed against `doc/architecture.md`.

## More Information

The layers, the areas and what each may depend on are in [the architecture](../architecture.md). [ADR-0017](0017-use-cases-hold-the-rules-that-need-two-areas.md) and [ADR-0018](0018-screens-are-objects-on-a-stack.md) are decisions made under this one. Revisit when the folders are divided by area, to say what then enforces the division.
