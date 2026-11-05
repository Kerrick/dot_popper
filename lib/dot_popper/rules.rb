# frozen_string_literal: true

module DotPopper
  # The numbers that make the game what it is. Every distance and speed is
  # measured in radii, so the game plays the same on any screen once the
  # radius itself is known (see DotSize).
  module Rules
    # A dot's radius, in Lota's graphics units. With +t.highdpi+ on, those
    # are logical pixels on a desktop and points on a phone or tablet.
    RADIUS = 50

    # Each axis of a new dot's velocity is one of these, in radii per
    # second, with a random sign. The original moved 1 to 5 pixels a frame
    # at 60 frames a second with a radius of 50.
    SPEEDS = [1.2, 2.4, 3.6, 4.8, 6.0].freeze

    STARTING_SECONDS = 10.0

    POP_POINTS = 1
    POP_SECONDS = 1.0

    PENALTY_POINTS = 2
    PENALTY_SECONDS = 2.0

    LOWEST_SCORE = 0

    # A fresh dot spawns at a uniformly random place with a random
    # velocity, but must offer a touch target within SPAWN_LOOKAHEAD
    # seconds: a circle TOUCH_TARGET units across, wholly on the dot and
    # clear of every dot above it. TOUCH_TARGET is Apple's smallest
    # comfortable touch target, 44 points, and the same 44 logical pixels
    # under a mouse. A draw that offers none tries another velocity, up to
    # SPAWN_TRIES times, then another place and velocity, up to SPAWN_TRIES
    # more, and keeps its last draw if every try fails, so a dot always
    # spawns. See Spawner, and doc/decisions.md for how rarely it applies.
    TOUCH_TARGET = 44
    SPAWN_LOOKAHEAD = 1.0
    SPAWN_TRIES = 4

    # The most time one frame may pass on to the rules. A frame that took
    # longer, because the window was dragged, the app was in the
    # background, or the computer stalled, did not give the player that
    # time to play, so it must not take it off the clock either.
    LONGEST_FRAME = 0.1

    # How long Game Over ignores presses, so a tap meant for a dot in the
    # round's last moment does not dismiss the final score unseen.
    GAME_OVER_GRACE = 0.9

    # Records are kept by the field's size in square radii (SizeClass),
    # because a smaller field crowds sooner, and crowding is the game's
    # difficulty. With R fixed, the simulation (doc/decisions.md) has an
    # upright iPhone at 134 R², an 11-inch iPad and the 24 × 16 R desktop
    # window at about 384, a 13-inch iPad Pro at 566, and big monitors
    # fullscreen at 1,475 to 2,035. A field under SMALL_FIELD_BELOW is
    # phone-sized; one of LARGE_FIELD_FROM or more is a large monitor's;
    # tablets and the desktop window fall between. The cut-offs sit in
    # the wide gaps between those devices, so a window resized a little
    # stays in its class.
    SMALL_FIELD_BELOW = 250
    LARGE_FIELD_FROM = 700

    # "Sized to your screen" (DotSizing), which the player may choose in
    # place of the fixed RADIUS: each round's radius is the one that makes
    # its field FITTED_AREA square radii, the 24 × 16 R desktop window's
    # area, so every screen is as crowded as that one. It is never below
    # SMALLEST_FITTED_RADIUS, 30 units, a dot 60 points across, well over
    # Apple's 44-point smallest touch target; and never above
    # LARGEST_FITTED_SHARE of the screen's shorter side, so a dot on a long,
    # thin window stays a dot and not a wall.
    FITTED_AREA = 24 * 16
    SMALLEST_FITTED_RADIUS = 30
    LARGEST_FITTED_SHARE = 1 / 7.0
  end
end
