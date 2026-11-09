# frozen_string_literal: true

module DotPopper
  module Presentation
    # How hard and how long the screen shakes: +amplitude+ in radii,
    # +duration+ in seconds, +frequency+ in shakes a second.
    class ShakeStyle < Data.define(:amplitude, :duration, :frequency)
      # The largest shake allowed, in radii, so dots never jump far from
      # where a tap reaches them.
      LIMIT = 0.15

      def strength(elapsed)
        return 0.0 if elapsed.negative? || elapsed >= duration

        [amplitude, LIMIT].min * ((1 - (elapsed / duration))**2)
      end
    end

    # A shake that began at +born+, as the screen's offset at each moment.
    # It starts at full strength and dies away; +scale+ is the radius in
    # graphics units. A calm shake (DOT_POPPER_CALM) never moves.
    class Shake < Data.define(:style, :born, :scale, :calm)
      def self.none(scale, calm: false) = new(style: nil, born: -Float::INFINITY, scale:, calm:)

      def kick(style, now) = with(style:, born: now)

      def strength(now) = calm || style.nil? ? 0.0 : style.strength(now - born)

      def offset_x(now) = offset(now, 1.0, 0.0)
      def offset_y(now) = offset(now, 1.37, 1.9)

      private

      def offset(now, rate, phase)
        strength = strength(now)
        return 0.0 if strength.zero?

        strength * scale * Math.sin(((now - born) * style.frequency * rate * 2 * Math::PI) + phase)
      end
    end
  end
end
