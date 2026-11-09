# frozen_string_literal: true

module DotPopper
  module Shell
    # The droplets of a pop and the twinkles of a new record, flown and drawn
    # by LÖVE's ParticleSystem. Each sprite is drawn in code into an
    # ImageData at the screen's density, so it is as sharp as the dots.
    # A system's colors run through each particle's life, so there is one
    # system for each Burst and color, made the first time it is needed
    # and reused; a pop emits its share of droplets from each of its
    # colors' systems. Without a sprite, there are no droplets, and the
    # game goes on.
    class Sparks
      G = ::Lota::Graphics
      BUFFER = 4 # bursts of one look each system has room for at once

      def initialize(style)
        @style = style
        @systems = {}
        @cleared = 0
        refresh
      end

      # Draws the sprites again, at the screen's density now.
      def refresh
        @sprites = %i[droplet twinkle].to_h { [it, sprite(it)] }
        @systems.clear
      rescue StandardError => e
        warn "Dot Popper: drawing without droplets (#{e.message})"
        @sprites = {}
      end

      # Throws the bursts the effects ask for, then moves every particle.
      def update(seconds, effects)
        @systems.each_value(&:reset) if effects.cleared != @cleared
        @cleared = effects.cleared
        effects.take_sprays.each { |spray| emit(spray, effects.shares(spray)) }
        @systems.each_value { it.update(seconds) }
      end

      def draw
        G.color = [1, 1, 1, 1]
        @systems.each_value { G.draw(it, 0, 0) }
      end

      def count = @systems.each_value.sum(&:count)

      private

      def emit(spray, shares)
        shares.each do |color, count|
          next if count.zero?

          system = system_for(spray, color) or next
          system.move_to(spray.x, spray.y)
          system.emit(count)
        end
      end

      def system_for(spray, color)
        texture = @sprites[spray.style.sprite] or return
        @systems[[spray.style, spray.longest, spray.radius, color]] ||= configure(
          G::ParticleSystem.new(texture, spray.style.count * BUFFER), spray.emission(texture.width), color
        )
      end

      def configure(system, emission, color)
        system.particle_stats_book = emission.stats_book
        system.speed = emission.speed
        system.spread = 2 * Math::PI
        system.linear_damping = emission.damping
        system.linear_acceleration = emission.acceleration
        system.sizes = emission.sizes
        system.size_variation = emission.size_variation
        system.rotation = [0, 2 * Math::PI]
        system.spin = emission.spin
        system.spin_variation = 1
        system.colors = emission.colors(color)
        system.emission_rate = 0
        system
      end

      # A white sprite whose opacity is SpriteArt's, +@style::PARTICLE_SPRITE+
      # units across, in as many pixels as the screen has.
      def sprite(name)
        density = G.dpi_scale
        pixels = (@style::PARTICLE_SPRITE * density).ceil
        data = ::Lota::Image::ImageData.new(pixels, pixels, :rgba8)
        data.map_pixel { |x, y, *| [1, 1, 1, Presentation::SpriteArt.alpha(name, x, y, pixels)] }
        G::Image.new(data, dpiscale: density)
      end
    end
  end
end
