# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where across the stereo field a sound plays, from -1 (left) to 1
    # (right), so a pop is heard about where it is seen. +spread+ is the
    # most it leans to either side, which keeps both ears in every sound.
    class Stereo < Data.define(:spread)
      CENTER = 0.0

      # The pan for something at +x+ across a screen +width+ wide.
      def pan(x, width)
        return CENTER unless width.to_f.positive?

        spread * (((2.0 * x) / width) - 1).clamp(-1.0, 1.0)
      end

      # Where to put a mono source, relative to the listener, for +pan+:
      # on a circle of radius 1 in front of the listener, so OpenAL pans it
      # by its angle and its distance never softens it.
      def self.position(pan)
        angle = Math.asin(pan.clamp(-1.0, 1.0))
        [Math.sin(angle), 0.0, -Math.cos(angle)]
      end
    end
  end
end
