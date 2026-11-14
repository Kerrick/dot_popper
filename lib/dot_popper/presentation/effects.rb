# frozen_string_literal: true

module DotPopper
  module Presentation
    # Everything that plays out after a tap and then goes away: droplets,
    # rings, mistake outlines, floating numbers, the shake, and the edge flash. It
    # keeps its own clock, +now+; rings, floating texts, the shake, and the flash are
    # values that say how they look at a moment. Droplets are LÖVE's
    # particles, so a burst waits here as a PendingBurst until the shell takes
    # it; +cleared+ counts the clears, so the shell knows to drop the
    # droplets already flying. Sizes and speeds come in radii and leave in
    # graphics units, scaled by +radius+, the game's dots' (#scale_to).
    class Effects
      MOST_RINGS = 32
      MOST_FLOATING_TEXTS = 24

      MOST_PENDING_BURSTS = 16

      attr_reader :rings, :mistake_outlines, :floating_texts, :shake, :flash, :now, :cleared

      def initialize(radius:, random: Random.new, calm: false)
        @radius = radius
        @random = random
        @now = 0.0
        @cleared = 0
        @bursts = []
        @rings = []
        @mistake_outlines = []
        @floating_texts = []
        @shake = Shake.none(radius, calm:)
        @flash = EdgeFlash::NONE
      end

      # Throws +style.count+ droplets out from (+x+, +y+), shared among
      # +colors+. No droplet outlives +longest+, which only a screen with
      # no game in play may raise.
      def burst(x, y, style, colors, longest: Burst::LONGEST_LIFE)
        burst = PendingBurst.new(x:, y:, style:, colors:, longest: [longest, style.life.end].min, radius: @radius)
        keep(@bursts, burst, MOST_PENDING_BURSTS)
      end

      # The bursts asked for since the last call, which the shell throws.
      def take_bursts
        bursts = @bursts
        @bursts = []
        bursts
      end

      # How many droplets of +burst+ each of its colors gets.
      def shares(burst) = burst.style.shares(burst.colors, @random)

      def ring(x, y, style, follow: nil)
        keep(@rings, Ring.new(x:, y:, style:, scale: @radius, born: now, follow:), MOST_RINGS)
      end

      # Outlines +dot+, wherever it goes, over every other dot.
      def outline(dot, style)
        keep(@mistake_outlines, MistakeOutline.new(follow: dot.id, x: dot.x, y: dot.y, style:, scale: @radius, born: now), MOST_RINGS)
      end

      def float(text, x, y, color, style)
        keep(@floating_texts, FloatingText.new(text:, x:, y:, color:, style:, scale: @radius, born: now), MOST_FLOATING_TEXTS)
      end

      # Measures every effect from now on in dots of +radius+, as a game
      # whose dots are standard for the screen needs. Effects already playing
      # keep the size they began with.
      def scale_to(radius)
        @radius = radius
        @shake = @shake.with(scale: radius)
      end

      def kick(style) = @shake = @shake.kick(style, now)
      def light(style) = @flash = EdgeFlash.new(style:, born: now)

      def shake_x = @shake.offset_x(now)
      def shake_y = @shake.offset_y(now)
      def flash_alpha = @flash.alpha(now)

      def update(seconds)
        @now += seconds
        @rings.select! { it.alive?(now) }
        @mistake_outlines.select! { it.alive?(now) }
        @floating_texts.select! { it.alive?(now) }
      end

      def clear
        @cleared += 1
        @bursts.clear
        @rings.clear
        @mistake_outlines.clear
        @floating_texts.clear
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
