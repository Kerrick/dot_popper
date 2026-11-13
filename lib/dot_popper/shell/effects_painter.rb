# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws what follows a tap: rings (each around its dot, if it follows
    # one), the droplets that Sparks flies, and floating numbers, outlined
    # so they read over any dot.
    class EffectsPainter < Data.define(:pen, :sparks)
      G = ::Lota::Graphics
      EDGE_BANDS = 8 # strips of the edge glow, without its shader

      # The rings, the reveals of a hidden bright dot, and the droplets.
      def scene(effects, dots)
        rings(effects.rings, effects.now, dots)
        reveals(effects.reveals, effects.now, dots)
        droplets
      end

      # The floating numbers, over everything, glow included.
      def words(effects, layout) = floaters(effects.floaters, effects.now, layout)

      # Additive, so droplets only ever brighten.
      def droplets = pen.adding { sparks.draw }

      # The glow at the screen's edges, over everything in the field.
      def flash(effects, width, height)
        alpha = effects.flash_alpha
        return if alpha <= 0.0

        band = [width, height].min * effects.flash.band
        return flat_flash(pen.themed(effects.flash.color), alpha, width, height, band) unless pen.shader?(:edge)

        pen.shading(:edge) do |shader|
          pen.uniform(shader, "size", [width.to_f, height.to_f])
          pen.uniform(shader, "band", band)
          pen.color(pen.themed(effects.flash.color), alpha)
          pen.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      private

      def rings(rings, now, dots)
        rings.each do |ring|
          width = ring.width(now)
          next if width <= 0.0

          x, y = ring.center(dots)
          pen.color(pen.themed(ring.style.color), ring.alpha(now))
          G.line_width = width
          G.circle(:line, x, y, ring.radius(now), 64)
        end
      end

      # Each hidden dot's outline, in dashes, over a darker one so it reads
      # over a light dot as well as a dark one.
      def reveals(reveals, now, dots)
        reveals.each do |reveal|
          x, y = reveal.center(dots)
          radius = reveal.radius(now)
          alpha = reveal.alpha(now)
          [[pen.palette.shadow, reveal.width * 2.2, alpha * 0.5], [pen.themed(reveal.style.color), reveal.width, alpha]]
            .each do |color, width, strength|
            pen.color(color, strength)
            G.line_width = width
            reveal.dashes(now).each { |from, to| G.arc(:line, :open, x, y, radius, from, to, 10) }
          end
        end
      end

      def floaters(floaters, now, layout)
        return if floaters.empty?

        font = pen.fonts.bold(layout.scaled(pen.style::TYPE.floater))
        floaters.each { pen.outlined(it.text, font, it.x, it.y_at(now), it.color, it.alpha(now)) }
      end

      # Strips along each edge, fainter toward the middle.
      def flat_flash(color, alpha, width, height, band)
        step = band / EDGE_BANDS
        EDGE_BANDS.times do |i|
          pen.color(color, alpha * ((1 - (i.to_f / EDGE_BANDS))**2) * 0.5)
          inset = i * step
          G.rectangle(:fill, inset, inset, width - (2 * inset), step)
          G.rectangle(:fill, inset, height - inset - step, width - (2 * inset), step)
          G.rectangle(:fill, inset, inset + step, step, height - (2 * (inset + step)))
          G.rectangle(:fill, width - inset - step, inset + step, step, height - (2 * (inset + step)))
        end
      end
    end
  end
end
