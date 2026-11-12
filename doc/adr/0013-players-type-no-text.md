---
status: accepted
date: 2026-11-08
deciders: the maintainer (Kerrick Long)
---

# Players type no text: friend-group members are drawn icons, and codes are digits

## Context and Problem Statement

Friend groups let a few invited friends compete for one title. A first build had typed names, a word filter, Report and Block. Text a player writes, shown to other players, brings moderation duties (Apple's guideline 1.2 for user-generated content: filtering, reporting, blocking, published contact), risk to players, and a liability for setdef. How are players identified to each other, and how do they find a group, with no text a player writes?

## Decision Drivers

* The maintainer's decision, as the record states it: any text a player enters is a liability. `AGENTS.md` makes it a rule: players type no text, and nothing a player could type is stored or shown to anyone else.
* Members must tell each other apart in grayscale and for colour-blind players (Johnson, *Designing with the Mind in Mind*, on not relying on colour alone; Westland and Maggio).
* Joining must work by touch or a controller alone, with no keyboard.
* A code must not spell a word in any language, and must resist guessing.

## Considered Options

1. No text at all: within a group a member is a number, which the game draws as an icon worked out from the number and the group's id; a group is joined by a seven-digit code the server makes, tapped on a keypad.
2. Typed names, with a filter, Report and Block (the first build).

## Decision Outcome

Chosen: option 1, the maintainer's decision. Seven digits give ten million codes against the server's limit of twenty tries an hour for a player, and digits make no word in any language. The record reads Apple's guideline 1.2 (as read on 2026-11-08) as not applying to an app where a player writes nothing and other players see only what the game draws; that is a reading, not legal advice. Confidence: high that no player text reaches the server or another player; the server accepts no name and the game sends none.

The record's first version of this decision also counted any word the game picks to stand for a person as a liability. The screen redesign the maintainer approved since gives each group and member a name the game makes from hand-picked word lists (`Presentation::Names`: "Brave Puffins", "Purple Kiwi"), worked out from the ids as icons are, so the server stores none. That part of the first version is not in force.

### Consequences

* Good, because the server has no name column, no rename, and nothing to moderate: there is no filter, blocklist, Report or Block.
* Good, because names and icons are the same on every device and need no storage.
* Bad, because players can't choose how they appear, and a group's code has to be shared outside the game.
* Bad, because the game's word lists must stay free of unkind words and second meanings (`test/presentation/names_test.rb` tries every pair against a list of bad words).
* Neutral, because a keyboard may type a code's digits, and a website copy's license key may be typed on its offer; neither is shown to anyone else.

### Confirmation

`test/presentation/member_icon_test.rb` and `names_test.rb` test icons and names; `test/privacy/requests_test.rb` checks every request's fields on the wire, so a field carrying text would show. The server's own API (`docs/api.md` in the server's repository) accepts no free text.

## More Information

The client, icons, names, codes and screens are in [friend groups](../design/friend-groups.md); what the server does is in [doc/server.md](../server.md).
