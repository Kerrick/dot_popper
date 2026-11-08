# frozen_string_literal: true

module DotPopper
  module Presentation
    # The hand the Tutorial's guide draws for a touchscreen: the familiar
    # emoji for "tap here", Noto Emoji's backhand index pointing up
    # (U+1F446, Apache-2.0; assets/emoji/README.md), drawn upright, its
    # fingertip on the point it taps and the hand below it. It comes as
    # square PNGs of SIZES pixels (script/make_hand.rb renders them from
    # the SVG, VIEW of its 128-unit square each), and the shell draws the
    # smallest that is at least as many pixels as it needs, a little
    # smaller, with linear filtering and mipmaps, as an icon is drawn.
    #
    # Points in it are fractions of the PNG's side from its top left: TIP,
    # just inside the fingertip's top, is the point it taps, and WRIST,
    # the middle of its wrist's bottom edge, is what it turns about as it
    # wags its finger. REACH is how far the hand reaches right of its tip
    # and down from it, in the PNG's side.
    module PointingHand
      SIZES = [48, 64, 96, 128, 192, 256, 384, 512].freeze
      VIEW = [3, 3, 122, 122].freeze # the PNG's square of the SVG: min x, min y, width, height
      TIP = [51.7, 8.5].freeze # in the SVG's units
      WRIST = [79.0, 121.5].freeze
      RIGHT = 106.9 # the hand's rightmost and lowest points, in the SVG's units
      BOTTOM = 121.6
      PRESS = 0.06 # how much smaller the hand is as it presses, as if pushed into the screen

      def self.fraction((x, y)) = [(x - VIEW[0]) / VIEW[2].to_f, (y - VIEW[1]) / VIEW[3].to_f]

      TIP_AT = fraction(TIP).freeze
      WRIST_AT = fraction(WRIST).freeze
      REACH = [(RIGHT - TIP[0]) / VIEW[2].to_f, (BOTTOM - TIP[1]) / VIEW[3].to_f].freeze

      # The side, in pixels, of the PNG to draw for a hand +pixels+ across:
      # the smallest that has at least as many, or the largest.
      def self.size_for(pixels) = SIZES.find { it >= pixels } || SIZES.last

      # Which way the hand faces with its tip at +x+, its PNG +side+
      # graphics units across, on a screen +width+ across: 1, as drawn,
      # or -1, mirrored, where the right edge would cut it off. It is
      # never turned upside down: the Tutorial keeps the dots it taps clear
      # of the bottom.
      def self.facing(x, side, width) = x + (REACH[0] * side) > width ? -1 : 1
    end
  end
end
