# frozen_string_literal: true

module DotPopper
  module Shell
    # The Tutorial's skip button: a disc with ⏭ drawn on it, two arrows
    # and a bar, and no word. A tap anywhere on it starts the round (Show#tap).
    # With the mouse over it, +hover+ of the way (Presentation::Hover), it
    # brightens as the title's buttons do.
    class SkipButton < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(rect, hover: 0.0)
        pixels = pen.pixels
        lit = pen.lit
        size = rect.width
        x = pixels.snap(rect.center_x)
        y = pixels.snap(rect.center_y)
        fill = pen.palette.pill.mix(lit.fill, hover)
        pen.color(fill, [fill.a, 0.8].max)
        G.circle(:fill, x, y, size / 2.0, 48)
        pen.color(pen.palette.soft.mix(lit.edge, hover), 0.55 + (0.45 * hover))
        G.line_width = pixels.line_width(1)
        G.circle(:line, x, y, (size / 2.0) - (pixels.line_width(1) / 2.0), 48)
        pen.color(pen.palette.cream.mix(lit.edge, hover))
        icon(x, y, size / 100.0)
      end

      private

      # ⏭: two arrows pointing on, and the bar they stop at.
      def icon(x, y, u)
        pixels = pen.pixels
        top = y - (13 * u)
        bottom = y + (13 * u)
        [-21, -5].each { G.polygon(:fill, x + (it * u), top, x + ((it + 15) * u), y, x + (it * u), bottom) }
        G.rectangle(:fill, pixels.snap(x + (12 * u)), pixels.snap(top), pixels.whole(5 * u),
                    pixels.snap(bottom) - pixels.snap(top))
      end
    end
  end
end
