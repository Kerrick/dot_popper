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

    # The most time one frame may pass on to the rules. A frame that took
    # longer, because the window was dragged, the app was in the
    # background, or the computer stalled, did not give the player that
    # time to play, so it must not take it off the clock either.
    LONGEST_FRAME = 0.1

    # How long Game Over ignores presses, so a tap meant for a dot in the
    # round's last moment does not dismiss the final score unseen.
    GAME_OVER_GRACE = 0.9
  end
end
