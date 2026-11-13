# frozen_string_literal: true

module DotPopper
  module Presentation
    # A color as Lota takes one: red, green, blue, and alpha, each from 0
    # to 1, in sRGB.
    class Color < Data.define(:r, :g, :b, :a)
      # The color written as "#rrggbb", with +a+ for its alpha.
      def self.hex(text, a = 1.0)
        value = Integer(text.delete_prefix("#"), 16)
        new(r: ((value >> 16) & 255) / 255.0, g: ((value >> 8) & 255) / 255.0, b: (value & 255) / 255.0, a:)
      end

      def initialize(r:, g:, b:, a: 1.0) = super(r: r.to_f, g: g.to_f, b: b.to_f, a: a.to_f)

      def with_alpha(alpha) = with(a: alpha.to_f)

      # The same color, +factor+ times as opaque.
      def fade(factor) = with(a: a * factor)

      # The color +amount+ of the way to +other+: 0 is this color, 1 is
      # +other+.
      def mix(other, amount)
        Color.new(r: r + ((other.r - r) * amount), g: g + ((other.g - g) * amount),
                  b: b + ((other.b - b) * amount), a: a + ((other.a - a) * amount))
      end

      def to_a = [r, g, b, a]

      # The color as 8-bit channels, for building images.
      def bytes = [r, g, b, a].map { (it.clamp(0.0, 1.0) * 255).round }

      # Relative luminance, as WCAG defines it: how light the color looks,
      # from 0 for black to 1 for white, whatever its hue. Bright and popped
      # dots are told apart by this, not only by hue.
      def luminance
        red, green, blue = [r, g, b].map { linear(it) }
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
      end

      # WCAG's contrast ratio with +other+, from 1 to 21.
      def contrast(other)
        light, dark = [luminance, other.luminance].minmax.reverse
        (light + 0.05) / (dark + 0.05)
      end

      private

      def linear(channel) = channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
  end
end
