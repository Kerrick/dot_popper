# frozen_string_literal: true

module DotPopper
  module Presentation
    # The hand the Tutorial's guide draws for a touchscreen, and "How to
    # play" draws on its button: the familiar sign for "tap here", a
    # gloved hand with its index finger out and the other fingers curled
    # into a fist, the thumb across them, and a cuff at the wrist. It is
    # made of rounded rectangles and capsules, in units of the finger's
    # width, pointing straight up with its fingertip's pad on 0, 0, the
    # point it taps; it is drawn tilted by TILT, so it reaches in from
    # below and to the right, clear of the dot it taps.
    #
    # Each of its PARTS is a group of shapes drawn as one: first its
    # outline, the shapes grown by the outline's width, then the shapes.
    # Later groups lie over earlier ones, so the curled fingers and the
    # thumb are each outlined where they cross the palm, as creases.
    module PointingHand
      # A rectangle from +x+, +y+, +width+ by +height+, its corners rounded
      # by +corner+.
      class RoundRect < Data.define(:x, :y, :width, :height, :corner)
        def grown(by) = with(x: x - by, y: y - by, width: width + (2 * by), height: height + (2 * by), corner: corner + by)
        def points = [[x, y], [x + width, y], [x, y + height], [x + width, y + height]]
      end

      # A bar +width+ across from +from+ to +to+ (each [x, y]), with round
      # ends.
      class Capsule < Data.define(:from, :to, :width)
        def grown(by) = with(width: width + (2 * by))

        def points
          half = width / 2.0
          [from, to].flat_map { |x, y| [[x - half, y - half], [x + half, y + half]] }
        end
      end

      TILT = -0.5 # radians: the finger leans up and to the left
      PRESS = 0.06 # how much smaller the hand is as it presses, as if pushed into the screen

      PARTS = [
        [RoundRect.new(x: -0.45, y: 4.8, width: 2.5, height: 0.95, corner: 0.2)], # the cuff
        [RoundRect.new(x: -0.5, y: -0.3, width: 1.0, height: 3.5, corner: 0.5), # the index finger
         RoundRect.new(x: -0.6, y: 2.4, width: 2.7, height: 2.6, corner: 0.75)], # and the palm, one shape
        [RoundRect.new(x: 0.5, y: 2.45, width: 1.75, height: 0.75, corner: 0.37)], # the curled fingers
        [RoundRect.new(x: 0.5, y: 3.2, width: 1.75, height: 0.75, corner: 0.37)],
        [RoundRect.new(x: 0.5, y: 3.95, width: 1.65, height: 0.75, corner: 0.37)],
        [Capsule.new(from: [-0.35, 4.3], to: [0.95, 3.55], width: 0.8)] # the thumb, across them
      ].freeze

      # The hand's tilted bounds around its tip, in units, as
      # [left, top, right, bottom].
      BOUNDS = PARTS.flatten.flat_map(&:points).map do |x, y|
        [(x * Math.cos(TILT)) - (y * Math.sin(TILT)), (x * Math.sin(TILT)) + (y * Math.cos(TILT))]
      end.transpose.then { |xs, ys| [xs.min, ys.min, xs.max, ys.max] }.freeze

      # Which way the hand faces with its tip at +x+, +y+, at +unit+
      # graphics units to its finger's width, on a screen +width+ by
      # +height+, as [across, down]: each 1, as drawn, or -1, mirrored. It
      # reaches in from below and to the right, from the left where the
      # right edge would cut it off, and from above where the bottom
      # would.
      def self.facing(x, y, unit, width, height)
        _, _, right, bottom = BOUNDS
        [x + (right * unit) > width ? -1 : 1, y + (bottom * unit) > height ? -1 : 1]
      end
    end
  end
end
