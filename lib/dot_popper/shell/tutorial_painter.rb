# frozen_string_literal: true

module DotPopper
  module Shell
    # What the Tutorial draws over its dots and the HUD, with no word: the
    # dim around its spotlight, the numbers flying to and from the HUD, the
    # guide (GhostPainter), and the skip button; and, in the game's first
    # moments, its ClockHighlight, the light on the clock. The HUD itself
    # is never dimmed, and the number the spotlight is on is
    # haloed. Text and lines sit on whole device pixels.
    #
    # The dim is drawn without a stencil (the window has none): rings of
    # quads from the light's edge out past the screen's corners, a few one
    # inside the next, so its edge feathers out.
    class TutorialPainter < Data.define(:pen)
      G = ::Lota::Graphics
      SEGMENTS = 64
      LAYERS = 8 # rings in the dim's soft edge
      HUD_LIGHT = 0.8 # the light's reach around a HUD number, in the HUD's height
      DOTS_IN_A_ROW_LIGHT = 1.35 # the same, around the row's row

      # What goes under the HUD, which is never dimmed, so its numbers
      # always show where they live: the dim around the Tutorial's (+scene+)
      # spotlight, with the HUD at +pill+ and its numbers' middles at
      # +spots+.
      def under_hud(scene, pill, spots)
        spotlight(scene.spotlight, scene.now, scene.dots, spots, scene.radius, pill)
      end

      # What goes over the HUD: a halo on the number the spotlight is on,
      # the numbers in flight, the guide, and the skip button.
      def over_hud(show, scene, layout, pill, spots)
        now = scene.now
        light = scene.spotlight
        halo(light.to.name, pill, light.strength(now), now - light.at) if light.to&.hud? && light.to.name != :dots_in_a_row
        row_ring(scene.row_notice, now, spots.fetch(:dots_in_a_row), pill, scene.hud.size) if scene.row_notice
        font = pen.fonts.bold(layout.scaled(pen.style::TYPE.floater))
        scene.flights.each { flight(it, now, scene.dots, spots, scene.radius, font) }
        GhostPainter.new(pen:).draw(scene.ghost_pose, show.input, scene.radius)
        return unless show.skip_reach

        # Skip, bottom right, its sign before its word, so it reads without English.
        PillButton.new(pen:).draw(layout.skip_button, show.words.button(:skip), hover: show.hover.level(:skip),
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(:skip, x, y, size * 0.36) })
      end

      # The clock lit as the game's first second runs (Presentation::
      # ClockHighlight): the dim, under the HUD at +pill+...
      def lead_in_under(lead_in, now, pill, spots, radius)
        x, y = spots.fetch(:time)
        strength = lead_in.strength(now)
        style = pen.style::TUTORIAL.spotlight
        dim_around(x, y, pill.height * HUD_LIGHT, style.feather * radius, style.dim * strength) if strength.positive?
      end

      # ...and the halo on the clock, over it.
      def lead_in_over(lead_in, now, pill) = halo(:time, pill, lead_in.halo(now), now - lead_in.at)

      private

      # A pulsing outline around the score's or the time's half (+name+) of
      # the HUD's pill, +alpha+ of it, +age+ seconds after it lit.
      def halo(name, pill, alpha, age)
        return unless alpha.positive?

        pixels = pen.pixels
        pulse = (Math.cos(age * 2 * Math::PI) + 1) / 2
        grow = pixels.snap(pill.height * (0.06 + (0.05 * pulse)))
        half = pill.width / 2.0
        left = pixels.line_at((name == :score ? pill.x : pill.x + half) - grow, 2)
        top = pixels.line_at(pill.y - grow, 2)
        width = pixels.snap(half + (2 * grow))
        height = pixels.snap(pill.height + (2 * grow))
        corner = height / 2.0
        pen.color(pen.palette.gain, alpha * (0.55 + (0.4 * pulse)))
        G.line_width = pixels.line_width(2)
        G.rectangle(:line, left, top, width, height, corner, corner, 32)
      end

      # A ring around the row of dots in a row of +size+, hung at +spot+ as
      # the HUD draws it, pulsing as it fades: mint as it counts a pop, the
      # alarm's color as a mistake empties it.
      def row_ring(notice, now, spot, pill, size)
        strength = notice.strength(now)
        return unless strength.positive?

        palette = pen.palette
        pixels = pen.pixels
        radius = pill.height * Presentation::Hud::PIP
        reach = radius * 1.9
        half = (radius * Presentation::Hud::PIP_STEP * (size - 1) / 2.0) + reach
        pulse = (Math.cos((now - notice.at) * 2 * Math::PI * 2.0) + 1) / 2
        pen.color(notice.tone == :alarm ? palette.alarm : palette.gain, strength * (0.55 + (0.4 * pulse)))
        G.line_width = pixels.line_width(2)
        G.rectangle(:line, pixels.line_at(spot[0] - half, 2), pixels.line_at(spot[1] - reach, 2),
                    pixels.snap(2 * half), pixels.snap(2 * reach), reach, reach, 32)
      end

      # The light moves from one place to the next, its size with it; with
      # nothing at one end, it fades in or out at the other.
      def spotlight(light, now, dots, spots, radius, pill)
        darkness = light.darkness(now)
        return if darkness <= 0.0

        ends = [light.from, light.to].map { it && circle(it, dots, spots, radius, pill) }
        from, to = ends.map { it || ends.compact.first }
        return unless from

        share = light.progress(now)
        x, y, reach = from.zip(to).map { |start, finish| start + ((finish - start) * share) }
        dim_around(x, y, reach, light.style.feather * radius, darkness)
      end

      # The light around +anchor+, as [x, y, radius].
      def circle(anchor, dots, spots, radius, pill)
        x, y = anchor.point(dots, spots, radius)
        return unless x

        [x, y, reach(anchor, pill, radius)]
      end

      # How far the light reaches around +anchor+: the row's row is wider
      # than one number.
      def reach(anchor, pill, radius)
        return radius * pen.style::TUTORIAL.spotlight.dot unless anchor.hud?

        pill.height * (anchor.name == :dots_in_a_row ? DOTS_IN_A_ROW_LIGHT : HUD_LIGHT)
      end

      # The night's ink over everything but a circle of +light+ around +x+,
      # +y+, darkening over +feather+ to +alpha+.
      def dim_around(x, y, light, feather, alpha)
        width, height = G.dimensions
        far = (Math.hypot(width, height) * 1.1) + light + feather
        layer = 1 - ((1 - alpha)**(1.0 / LAYERS))
        pen.color(pen.palette.ink_bottom, layer)
        LAYERS.times { ring(x, y, light + (feather * (it + 0.5) / LAYERS), far) }
      end

      def ring(x, y, inner, outer)
        step = 2 * Math::PI / SEGMENTS
        SEGMENTS.times do |i|
          a = i * step
          b = (i + 1) * step
          G.polygon(:fill, x + (inner * Math.cos(a)), y + (inner * Math.sin(a)), x + (outer * Math.cos(a)),
                    y + (outer * Math.sin(a)), x + (outer * Math.cos(b)), y + (outer * Math.sin(b)),
                    x + (inner * Math.cos(b)), y + (inner * Math.sin(b)))
        end
      end

      # A number in the air, and its stopwatch for a second.
      def flight(flight, now, dots, spots, radius, font)
        from = flight.from.point(dots, spots, radius)
        to = flight.to.point(dots, spots, radius)
        share = flight.progress(now)
        x = from[0] + ((to[0] - from[0]) * share)
        y = from[1] + ((to[1] - from[1]) * share)
        tally = Presentation::Tally.new(text: flight.text, stopwatch: flight.icon == :stopwatch, dot: flight.icon == :dot)
        TallyPainter.new(pen:).centered(tally, font, x, y, flight.color, flight.alpha(now))
      end
    end
  end
end
