---
status: accepted
date: 2026-11-05
deciders: coding agents; the maintainer set the requirement that the suite be fast and reliable
---

# GUI scenarios play the real game in real windows, on a driven clock

## Context and Problem Statement

The unit suite never runs the shell, the part that talks to Lota. A resize once called a method that was never defined, reached `trunk`, and was caught only when someone ran the game by hand. A static check (`test/shell/defined_calls_test.rb`, which uses Prism) now catches undefined calls, but only a running game catches a wrong argument to Lota, a callback that is never wired up, or a screen that fails to draw. How is the whole game, shell included, tested?

## Decision Drivers

* The maintainer asked that the suite be fast and reliable above all.
* Tests must not depend on the speed of the machine or the window system.
* CI has no display; the maintainer's Mac must not show windows.
* Checks should be about behaviour, which stays stable when the art changes.

## Considered Options

1. Start the real game with `bundle exec lota run` once per scripted scenario; a director, loaded only when `DOT_POPPER_SCENARIO` names one, steps each frame by the time the scenario asks for (a sixtieth of a second), pushes presses onto Lota's own event queue, checks behaviour and pixels as it goes, and exits 0 or 1.
2. Unit tests and the static defined-calls check only, with no window.
3. Render stills and compare them with recorded ones, as deckbuilder's `rake test:gui` does.

## Decision Outcome

Chosen: option 1, because it alone exercises the shell's real calls into Lota while staying deterministic: a driven clock plays the same on a busy runner as on an idle one, and a run takes seconds. Option 2 was kept alongside it, not instead. Option 3's still comparison was set aside in favour of checking behaviour; the stills it would make are kept as galleries outside the suite. The record says there was no good reason to avoid windows, since Xvfb gives CI a screen and a hidden session gives the Mac one. Confidence: high; the suite runs on every push.

### Consequences

* Good, because a scenario reaches `main.rb`'s callbacks by the path a player's press does, so wiring, drawing and resizing are tested end to end.
* Good, because a fixed seed, date (`DOT_POPPER_TODAY`), window size and save folder make every run play the same dots on any machine.
* Bad, because the suite needs a display (Xvfb and Openbox in CI, `script/with-openbox.sh`), so `bundle exec rake` leaves it out and it runs as `rake test:gui`.
* Bad, because what Lota can't queue (a joystick object) has to be stood in for (`DOT_POPPER_FAKE_GAMEPAD`, `DOT_POPPER_FAKE_DRAG`), and window-size scenarios need a display at least 1200 × 800 units.
* Neutral, because `main.rb`'s last line loads the director, which never runs in a normal launch.

### Confirmation

`.github/workflows/gui.yml` runs `rake test:gui` under `xvfb-run` on every push and pull request; `test/gui/scenarios_test.rb` fails unless each scenario quits with 0 after printing its checks. `AGENTS.md` requires the GUI scenarios before a push that could affect them.

## More Information

How the director works, how to write a scenario, and how to run a gallery are in [development](../design/development.md).
