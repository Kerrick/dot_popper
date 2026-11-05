# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws what follows a tap: rings, droplets (additive, so they only
    # ever brighten), and floating numbers.
    class EffectsPainter
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def draw(effects, layout)
        rings(effects.rings)
        droplets(effects.particles)
        floaters(effects.floaters, layout)
      end

      # The glow at the screen's edges, over everything in the field.
      def flash(flash, width, height)
        return if flash.alpha <= 0.0

        @pen.shading(:edge) do |shader|
          @pen.send(shader, "size", [width.to_f, height.to_f])
          @pen.send(shader, "band", [width, height].min * 0.16)
          @pen.color(flash.color, flash.alpha)
          @pen.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      private

      def rings(rings)
        rings.each do |ring|
          next if ring.width <= 0.0

          @pen.color(ring.look.color, ring.alpha)
          G.line_width = ring.width
          G.circle(:line, ring.x, ring.y, ring.radius, 64)
        end
      end

      def droplets(particles)
        @pen.adding do
          @pen.shading(:glow) do
            particles.each do |particle|
              @pen.color(particle.color, particle.alpha)
              @pen.square(particle.x, particle.y, particle.size, particle.size)
            end
          end
        end
      end

      def floaters(floaters, layout)
        return if floaters.empty?

        font = @pen.fonts.bold(layout.scaled(@pen.look::TYPE.floater))
        floaters.each { @pen.text(it.text, font, it.x, it.y, it.color, it.alpha) }
      end
    end
  end
end
