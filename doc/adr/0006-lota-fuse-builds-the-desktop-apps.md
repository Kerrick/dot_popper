---
status: accepted
date: 2026-11-05
deciders: the maintainer (Kerrick Long), who set the rule; coding agents chose the tool
---

# `lota fuse` builds every desktop app, from released tools only

## Context and Problem Statement

Most players don't have Ruby, so Dot Popper ships as a self-contained app for macOS, Windows and Linux, and as playtest kits. Lota's maintainer stopped building Dot Popper's kits, and the maintainer asked that Dot Popper build its own artifacts with Lota, using only released tools. Which tool builds the desktop apps?

## Decision Drivers

* Only released tools: a Lota release gem, checked against that release's `SHA256SUMS`, and a tagged Fledge.
* One way to build, so CI and a developer's machine make the same app.
* Each platform builds on its own runner, since Fledge builds only for the computer it runs on.

## Considered Options

1. `lota fuse`, Lota's documented way to share a game, which writes a Fledge project around the game and runs `fledge build` in it.
2. `bundle exec fledge build` from this repository's own `fledge.yml` and `bin/dot_popper` launcher.

## Decision Outcome

Chosen: option 1, because it is Lota's documented route and it did everything the Fledge build did, so there was no reason to keep a second way. Confidence: high; the Package workflow builds and plays each desktop app with it on every push to `trunk`.

### Consequences

* Good, because the app is what Lota supports, and its notices (`NOTICES.txt`) and lockfile checks come with it.
* Good, because `lota fuse --exclude` keeps repository-only files (tests, docs, scripts, hosts) out of the app.
* Bad, because `lota fuse` builds no phone app: the iOS and Android builds still use Fledge directly, by Lota's phone guide, with `bin/dot_popper` and `fledge.yml`'s `programs:` entry.
* Bad, because `lota fuse` chooses the Fledge it builds with, so a Fledge upgrade for the desktop apps waits for a Lota release.
* Neutral, because `fledge.yml` still holds the version every build takes.

### Confirmation

`.github/actions/fuse/action.yml` is the one build step, used by `package.yml` and `kits.yml`; each built app plays itself for 20 seconds with no Ruby on its PATH before it is uploaded.

## More Information

[PACKAGING.md](../../PACKAGING.md) describes the build, what goes into the app, and the playtest kits.
