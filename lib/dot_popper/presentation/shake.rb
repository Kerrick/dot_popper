# frozen_string_literal: true

module DotPopper
  module Presentation
    # How hard and how long the screen shakes: +amplitude+ in radii,
    # +duration+ in seconds, +frequency+ in shakes a second.
    class ShakeLook < Data.define(:amplitude, :duration, :frequency)
      # The largest shake allowed, in radii, so dots never jump far from
      # where a tap reaches them.
      LIMIT = 0.15
    end

    # The screen's shake at each moment. It starts at full strength and
    # dies away to nothing; a calm shake never moves.
    class Shake
      def initialize(scale, calm: false)
        @scale = scale
        @calm = calm
        @look = nil
        @age = 0.0
      end

      def kick(look)
        @look = look
        @age = 0.0
      end

      def update(seconds) = @age += seconds

      def offset_x = offset(1.0, 0.0)
      def offset_y = offset(1.37, 1.9)

      def strength
        return 0.0 if @calm || @look.nil? || @age >= @look.duration

        [@look.amplitude, ShakeLook::LIMIT].min * (1 - (@age / @look.duration))**2
      end

      private

      def offset(rate, phase)
        return 0.0 if strength.zero?

        strength * @scale * Math.sin((@age * @look.frequency * rate * 2 * Math::PI) + phase)
      end
    end
  end
end
