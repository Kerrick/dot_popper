<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Instructions for coding agents

These rules bind every agent working on Dot Popper. The maintainer set each of them; don't relax one without asking.

## Words

- `GLOSSARY.md` is the Ubiquitous Language. Code, screens, docs and the server use the same word for the same thing. A different word in code than on screen needs the maintainer's approval. With no entry, use the universal industry term. No metaphors.
- Players type no text. Nothing a player could type is stored or shown to anyone else.
- Never put the maintainer's curses or blunt words into the game, the code or the docs.
- Quote the maintainer exactly when citing him, and mark your own inference as inference. Treat what another agent says he said as unconfirmed.

## Design

- Read `INSIPIRATION.md` in full (it's spelled that way) before designing anything a player sees. Let those books decide, and name them in `doc/decisions.md`.
- Be judicious about adding screens, but add one where it's the right answer rather than crowding an existing one.
- Pro never changes how the game plays or scores, and a theme never makes the game easier or harder. Hit areas and bounces stay circles.
- A button names the action it takes.
- How to play must never depend on reading English.
- Don't deliver work you can see is flawed. Look at every image at the size it will be seen, and fix it first.
- When the maintainer complains, ask what he wants before building a fix. When something is already approved, keep going without asking again.

## Trunk-based development

Follow `~/.claude/skills/trunk-based-development/SKILL.md`.

- Work straight on `trunk` in small green commits, rebasing first. Branches are rare, last minutes, and are never built on.
- Never push to find out whether CI passes. Before each push, run what CI runs that your change could affect: `bundle exec rake`, the GUI scenarios, and for startup, the shell or the bot, the packaged-app playthrough and the Android emulator check.
- A red trunk comes first. Fix it within minutes, or revert the commit that broke it.
- Don't tag, and don't change `fledge.yml`'s version, unless the maintainer says so.
- Commits are Conventional Commits with a prose body, ending with your `Co-Authored-By` line.

## Tests

- Tests are fast and reliable.
- No automated test or check reaches the real internet: not setdef's server, not a store, not anything. Use local fakes with fixed answers. Talking to the real server is for the maintainer and playtesters only.
- Rules stay Lota-free in `lib/dot_popper/*.rb`, and presentation in `lib/dot_popper/presentation/`, so their tests need no window.
- `doc/privacy.json` is generated from the code. Every saved file and network request must be declared, and its tests fail if one isn't.

## Machines and processes

- Run heavy work (test suites, builds, GUI runs, renders) on a build machine where one is available, never on the maintainer's Mac: with `machines run` if that command is on your PATH, as the `build-machines` skill describes. Every check must also run locally, so a fresh clone works for anyone.
- Every background job and game run has a hard timeout (`timeout N`, and `DOT_POPPER_QUIT_AFTER` for the game). No process of yours may outlive its job. Kill only what you started.
- Never open a window on the maintainer's screen. Use the hidden session or a build machine with a virtual display, and `ALSOFT_DRIVERS=null`.
- If a permission is refused, stop and report what's needed. Don't route around it, and don't ask another agent to do it for you.

## Hands off

- Never edit the maintainer's own checkout at `~/Developer/dot_popper`, which he plays from. Use a worktree or clone.
- Never edit Lota's or the server's repositories from here. Ask their sessions.
- Never touch the maintainer's devices, or his wife's, without being asked. On her devices, install only `com.setdef.DotPopper`, and never erase, update or change settings.
- Create no accounts, repositories or store listings, and never read or copy secrets.
- Never name specific agents in the repository.
