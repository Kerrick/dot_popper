---
status: accepted
date: 2026-11-08
deciders: the maintainer (Kerrick Long), for Vulkan on Windows; coding agents, for the rest
---

# Renderers per platform, and a relaunch without Vulkan when it fails

## Context and Problem Statement

LÖVE tries its renderers in a fixed order, Vulkan first, whatever order a game lists, and falls back only when a renderer can't be created at all. A computer with a Vulkan driver but no GPU it can use (old integrated graphics, a virtual machine, a remote desktop, Xvfb) gets "Failed to initialize graphics" and can't play; this was found on the maintainer's Linux machine. Lota keeps LÖVE's behavior here by design, so the choice is the game's, in `conf.rb`. On Windows, though, the Xbox Game Bar's overlay shows over the game only with Vulkan. Which renderers may each platform use, and what happens when Vulkan can't start the game?

## Decision Drivers

* Everyone must be able to start the game, including store reviewers, who may test in virtual machines.
* On Windows, the Xbox button must open an overlay the player can see.
* A game this light gains nothing from Vulkan's speed on a computer.
* LÖVE picks its graphics module once per process, and Lota adds no fallback.
* The player should see one slower start, not an error.

## Considered Options

For the renderers:

1. OpenGL only on Linux; LÖVE's own order (Vulkan first) on Windows x64 and Android; Metal on Apple's systems.
2. OpenGL only on Windows and Linux.

On Windows the maintainer tried four combinations on his PC, connected to a TV:

| | TV's game mode | Xbox overlay | Alt+Tab |
|---|---|---|---|
| OpenGL, borderless | yes | no | instant |
| OpenGL, exclusive | yes | no | disruptive |
| Vulkan, borderless | no | yes | instant |
| Vulkan, exclusive | no | yes | barely worse |

For a start that Vulkan fails:

1. The game notes the failure in its save folder and at once runs itself again with Vulkan left out (`DOT_POPPER_NO_VULKAN=1`); for 30 days `conf.rb` leaves Vulkan out from the start.
2. The note alone, read on the next launch: works only on the second launch, after an error the player has to understand.
3. An in-process restart: impossible, since LÖVE picks its graphics module once per process. Lota 0.3.0's `"restart"` from the error handler replaces the process, but ends with status 1 and a log line when it can't, and silently on a phone.

## Decision Outcome

Chosen: renderer option 1, because no Windows combination gave both the TV's game mode and the overlay, and the maintainer chose the working overlay; Linux keeps OpenGL alone, the renderer LÖVE has supported longest. Android keeps Vulkan first because Lota 0.3.0's host fixed Vulkan's crash on going to the background, and a smoothness run found Vulkan and OpenGL ES tied. And start option 1, because it alone works on the first launch; the game keeps its own relaunch (`Presentation::Relaunch`) over Lota's restart, since that route is the one proven on GitHub's GPU-less Windows runner and handles a phone, which can't start itself, with a message asking the player to. The note lasts 30 days, not forever, because a driver update or a move to real hardware can make Vulkan work, and the overlay is the reason Vulkan is allowed. Confidence: high that the rescue works where tested (Linux under Xvfb, a Mac, GitHub's Windows runner); medium overall, since no real Windows PC with a Vulkan driver and no usable GPU has been tried, and a battery comparison of the Android renderers is still owed.

### Consequences

* Good, because the Xbox overlay works on Windows, and a PC that can't run Vulkan still plays after one slower start.
* Good, because the second run is told by an environment variable, not the note, so a save folder that can't be written still starts the game, and a second run never starts a third.
* Bad, because the rescue lives in `conf.rb`'s `Lota.errorhandler`, since the window opens before `main.rb` loads, and `conf.rb` must set the save folder before it reads the note.
* Bad, because a PC where Vulkan still fails pays one slower start a month.
* Bad, because under Vulkan a TV's game mode is lost, borderless or exclusive (Settings' Display offers both).

### Confirmation

`test/presentation/renderer_choice_test.rb` tests the choice, and `test/shell/vulkan_rescue_test.rb` what the rescue takes. The Package workflow's Windows job plays the fused app allowed only Vulkan and fails unless it ran its own exe again, drew with OpenGL, wrote `vulkan_failed.txt` and exited 0.

## More Information

The mechanics (`RendererChoice`, `VulkanFailure`, `Relaunch`, `Shell::VulkanRescue`, the errors rescued, `DOT_POPPER_RENDERERS`) are in [platforms](../design/platforms.md).
