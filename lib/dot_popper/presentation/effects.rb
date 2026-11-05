# frozen_string_literal: true

module DotPopper
  module Presentation
    # Everything that plays out after a tap and then goes away: droplets,
    # rings, floating numbers, the shake, and the edge flash. Each frame
    # moves them all along by the time that passed. Sizes and speeds come
    # in radii and leave in graphics units, scaled by +radius+.
    class Effects
      MOST_RINGS = 32
      MOST_FLOATERS = 24

      attr_reader :particles, :rings, :floaters, :shake, :flash

      def initialize(radius:, random: Random.new, calm: false, particle_capacity: 400)
        @radius = radius
        @random = random
        @particles = ParticlePool.new(particle_capacity)
        @rings = []
        @floaters = []
        @shake = Shake.new(radius, calm:)
        @flash = EdgeFlash.new
      end

      # Throws +look.count+ droplets out from (+x+, +y+), each a color
      # from +colors+. No droplet outlives +longest+, which only a screen
      # with no round in play may raise.
      def burst(x, y, look, colors, longest: Burst::LONGEST_LIFE)
        look.count.times do
          angle = @random.rand(0.0...(2 * Math::PI))
          speed = @random.rand(look.speed) * @radius
          @particles.launch(x:, y:, velocity_x: Math.cos(angle) * speed, velocity_y: Math.sin(angle) * speed,
                            life: [@random.rand(look.life), longest].min,
                            size: @random.rand(look.size) * @radius, color: colors.sample(random: @random),
                            drag: look.drag, gravity: look.gravity * @radius, alpha: look.alpha)
        end
      end

      def ring(x, y, look) = keep(@rings, Ring.new(x, y, look, @radius), MOST_RINGS)

      def float(text, x, y, color, look)
        keep(@floaters, Floater.new(text:, x:, y:, color:, look:, scale: @radius), MOST_FLOATERS)
      end

      def kick(look) = @shake.kick(look)
      def light(look) = @flash.trigger(look)

      def update(seconds)
        @particles.update(seconds)
        [@rings, @floaters].each do |list|
          list.each { it.update(seconds) }
          list.select!(&:alive?)
        end
        @shake.update(seconds)
        @flash.update(seconds)
      end

      def clear
        @particles.clear
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
