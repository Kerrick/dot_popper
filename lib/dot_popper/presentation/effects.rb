# frozen_string_literal: true

module DotPopper
  module Presentation
    # Everything that plays out after a tap and then goes away: droplets,
    # rings, floating numbers, the shake, and the edge flash. It keeps its
    # own clock, +now+; rings, floaters, the shake, and the flash are
    # values that say how they look at a moment. Droplets are LÖVE's
    # particles, so a burst waits here as a Spray until the shell takes
    # it; +cleared+ counts the clears, so the shell knows to drop the
    # droplets already flying. Sizes and speeds come in radii and leave in
    # graphics units, scaled by +radius+.
    class Effects
      MOST_RINGS = 32
      MOST_FLOATERS = 24

      MOST_SPRAYS = 16

      attr_reader :rings, :floaters, :shake, :flash, :now, :cleared

      def initialize(radius:, random: Random.new, calm: false)
        @radius = radius
        @random = random
        @now = 0.0
        @cleared = 0
        @sprays = []
        @rings = []
        @floaters = []
        @shake = Shake.none(radius, calm:)
        @flash = EdgeFlash::NONE
      end

      # Throws +look.count+ droplets out from (+x+, +y+), shared among
      # +colors+. No droplet outlives +longest+, which only a screen with
      # no round in play may raise.
      def burst(x, y, look, colors, longest: Burst::LONGEST_LIFE)
        keep(@sprays, Spray.new(x:, y:, look:, colors:, longest: [longest, look.life.end].min), MOST_SPRAYS)
      end

      # The bursts asked for since the last call, which the shell throws.
      def take_sprays
        sprays = @sprays
        @sprays = []
        sprays
      end

      # How many droplets of +spray+ each of its colors gets.
      def shares(spray) = spray.look.shares(spray.colors, @random)

      def ring(x, y, look, follow: nil)
        keep(@rings, Ring.new(x:, y:, look:, scale: @radius, born: now, follow:), MOST_RINGS)
      end

      def float(text, x, y, color, look)
        keep(@floaters, Floater.new(text:, x:, y:, color:, look:, scale: @radius, born: now), MOST_FLOATERS)
      end

      def kick(look) = @shake = @shake.kick(look, now)
      def light(look) = @flash = EdgeFlash.new(look:, born: now)

      def shake_x = @shake.offset_x(now)
      def shake_y = @shake.offset_y(now)
      def flash_alpha = @flash.alpha(now)

      def update(seconds)
        @now += seconds
        @rings.select! { it.alive?(now) }
        @floaters.select! { it.alive?(now) }
      end

      def clear
        @cleared += 1
        @sprays.clear
        @rings.clear
        @floaters.clear
      end

      private

      def keep(list, item, most)
        list.shift while list.size >= most
        list << item
        item
      end
    end
  end
end
