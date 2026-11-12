# frozen_string_literal: true

module DotPopper
  module Presentation
    # The screen's device pixels, +scale+ of them to a graphics unit (2 on
    # a Retina display). Text, the HUD, and lines are placed on whole
    # device pixels, so glyphs and edges stay crisp; only moving dots sit
    # between pixels, where smooth motion matters more.
    class Pixels < Data.define(:scale)
      def initialize(scale:) = super(scale: scale.to_f.positive? ? scale.to_f : 1.0)

      # +value+, in graphics units, moved to the nearest device pixel.
      def snap(value) = (value * scale).round / scale

      # A line +count+ device pixels wide, in graphics units.
      def line_width(count = 1) = [count.round, 1].max / scale

      # Where to put a line of +count+ device pixels' width at +value+ so
      # it covers whole pixels: an odd width sits on a pixel's center.
      def line_at(value, count = 1) = [count.round, 1].max.odd? ? snap(value) + (0.5 / scale) : snap(value)

      # The nearest whole number of device pixels to +value+ units, at
      # least one, in graphics units.
      def whole(value) = [(value * scale).round, 1].max / scale

      # A font size, in graphics units, rounded to a step of +step+, so a
      # size that animates uses only a few fonts.
      def self.font_size(size, step: 1) = [(size / step.to_f).round * step, 1].max
    end
  end
end
