# Decisions made overnight

The maintainer asked for a playable build by morning and for nothing short of a
real blocker to wait on a question. These are the calls made without him, each
with its reason, so any of them can be revisited after playtesting.

## Rules

- **The dot's radius is 50 Lota graphics units everywhere.** With `t.highdpi`
  on, those are logical pixels on a desktop and points (iOS) or dp (Android) on
  touch systems. Neither Lota nor LÖVE reports a display's physical density, so
  the spec's 8 mm touch target falls back to 50 units, which is 7.9 to 9.6 mm on
  current iPhones and iPads and 7.9 mm by Android's definition of a dp.
  `DotPopper::DotSize` holds the choice and its reason.
- **A window resized mid-round keeps its dots on screen.** The spec sizes the
  field when the game starts and says nothing about resizing. A resized window
  gives the round in play the new field, and dots outside it are moved to its
  edge. The next round starts on the new field.
- **Game Over ignores presses for 0.9 s** (`Rules::GAME_OVER_GRACE`), so a tap
  meant for a dot in the round's last instant does not dismiss the final score
  unseen. The spec asks for the flow to feel natural; this is the one timing
  rule added for it.

## The field's size, in radii

Because R is a fixed size, the field's size *in radii* varies about 15 times
between a phone held upright and a 6K monitor, and the game's central tension,
a fresh dot spawning under popped ones, depends on how crowded the field is.
`script/simulate.rb` plays the real rules with a model player (reaction time,
Fitts's law travel, waiting for the fresh dot to come out from under, an
occasional impatient tap) at each size. See its output in the commit that adds
it.

- **The desktop window opens at a reference size of 24 by 16 radii** (1200 by
  800 logical pixels), clamped to the screen, instead of most of the desktop.
  Under the model, that plays like an 11-inch iPad, so the Mac, the Windows PC,
  and the iPad give comparable rounds. The window is still resizable and goes
  fullscreen with F11, so a player can choose a sparser, easier field.
- **Phones are much harder, and the rules are unchanged for them.** An upright
  iPhone is 8 by 17 radii; the model scores about a quarter of what it scores on
  an iPad. Making phones easier needs a rule change (a radius that grows with
  the screen, a fixed arena, or time rewards scaled by area), which is the
  maintainer's call after playtesting, not ours.

Its output on 2026-11-05, 60 rounds per device (`bundle exec ruby script/simulate.rb 60`):

| Device | Area (R²) | Mean score | 90th pct | Mean round (s) | Penalties |
| --- | ---: | ---: | ---: | ---: | ---: |
| iPhone portrait | 134 | 6.0 | 12 | 16.5 | 6.6 |
| iPad 11" | 387 | 23.6 | 35 | 34.2 | 8.8 |
| iPad Pro 13" | 566 | 33.3 | 48 | 43.8 | 9.6 |
| Reference window 24×16 R | 384 | 20.8 | 31 | 31.5 | 7.2 |
| 27" 1440p fullscreen | 1475 | 62.8 | 84 | 73.3 | 7.4 |
| 32" 6K fullscreen | 2035 | 76.8 | 103 | 87.6 | 7.2 |

The model player is crude (its impatience sets the penalty count), so read the
columns against each other, not as predictions of a person's score.

## Presentation

- **One frame advances the rules by at most 0.1 s.** The spec has the clock
  count down in real time, using each frame's elapsed time. A long frame, such
  as dragging a window on Windows, a heavily loaded machine, or an iPad
  resuming, would otherwise take seconds off the clock while the player could
  not see or touch anything. Normal frames, down to 10 a second, are
  unaffected.
- **The look is "gumdrops at night."** Fresh dots are light, glossy, and
  haloed; popped dots are dark, matte, opaque discs with a light rim and a
  sunken crater, so the two differ in lightness (a 5.4:1 contrast ratio,
  enforced by a test) and in shape, not only in hue. Each dot's halo and shadow
  are drawn with the dot, in stack order, so a popped dot visibly covers a
  fresh one. The icon shows exactly that picture.
- **The sound setting is remembered** in the save folder (`sound.txt`), as is
  the best score (`best_score.txt`).
- **Every shader is optional.** If one fails to compile, the game says so once
  and draws plain shapes that keep the fresh/popped distinction
  (`DOT_POPPER_NO_SHADERS=1` forces this). Lota's CI drew the fused Windows
  build's title with Mesa's software OpenGL, shaders and all; no real Windows
  GPU has run it yet.

## Showing off LÖVE's engine

- **At game over the dots tumble into a pile, with Box2D.** Once time is up the
  rules are frozen and the dots are scenery, so `Shell::Pile` hands each one to
  a `Lota::Physics::World` as a ball of radius R, where it was and going as it
  went, between the window's floor and sides (open at the top). It falls behind
  the dimmed score and settles in about two seconds, and a new round or the
  title throws the world away; nothing in it can touch the score or the clock.
  One Box2D meter is 2 R, so a dot is a ball half a meter across, the size
  Box2D is tuned for. Each step is at most 1/30 s. `DOT_POPPER_CALM=1` makes it
  a slow, soft settle with no bounce. The autoplay bot waits 3.2 s at game over,
  not 1.8 s, so captures show the pile settled.
