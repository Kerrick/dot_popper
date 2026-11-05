# frozen_string_literal: true

module DotPopper
  module Presentation
    # How far the mouse has really moved since another kind of input was
    # last used, so a mouse that only seemed to move does not take over
    # the words and hide the gamepad's cursor. A window opening under the
    # pointer, or the pointer resting as a window resizes, sends a motion
    # event with no hand on the mouse; the first motion only says where
    # the pointer is.
    class MouseTravel < Data.define(:at, :distance)
      ENOUGH = 8.0 # graphics units: a deliberate nudge, not a jitter

      def self.start = new(at: nil, distance: 0.0)

      # The travel after a motion to (+x+, +y+).
      def moved(x, y)
        return with(at: [x, y]) unless at

        with(at: [x, y], distance: distance + Math.hypot(x - at[0], y - at[1]))
      end

      def deliberate? = distance >= ENOUGH
    end
  end
end
