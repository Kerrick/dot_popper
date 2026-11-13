# frozen_string_literal: true

module DotPopper
  module Shell
    # A Presentation::Tally drawn: its number, outlined so it reads over a
    # light dot or a dark one, and for the clock, the small stopwatch after
    # it, in the same color. The Tutorial flies these into the HUD, and
    # Home's legend shows the same ones, so they read as one language.
    class TallyPainter < Data.define(:pen)
      G = ::Lota::Graphics

      # +tally+ in +font+, its middle at +x+, +y+.
      def centered(tally, font, x, y, color, alpha)
        left(tally, font, x - (tally.width(font.height) { font.width(it) } / 2.0), y, color, alpha)
      end

      # +tally+ in +font+, from +x+ rightward, its middle at +y+.
      def left(tally, font, x, y, color, alpha)
        text = font.width(tally.text)
        pen.outlined(tally.text, font, x + (text / 2.0), y, color, alpha)
        return unless tally.stopwatch || tally.dot

        icon = Presentation::Tally.icon(font.height)
        middle = x + text + (icon * Presentation::Tally::GAP) + (icon / 2.0)
        tally.dot ? small_dot(middle, y, icon, color, alpha) : stopwatch(middle, y, icon, color, alpha)
      end

      # A small round dot, +size+ across, for a dot in the row, over a dark
      # edge.
      def small_dot(x, y, size, color, alpha)
        pixels = pen.pixels
        x = pixels.snap(x)
        y = pixels.snap(y)
        pen.color(pen.palette.shadow, alpha * 0.7)
        G.circle(:fill, x, y, (size * 0.42) + pixels.line_width(2), 32)
        pen.color(color, alpha)
        G.circle(:fill, x, y, size * 0.42, 32)
      end

      # A small stopwatch, +size+ across, centered on +x+, +y+: its face, a
      # hand, and the button on top, over a dark edge.
      def stopwatch(x, y, size, color, alpha)
        pixels = pen.pixels
        x = pixels.snap(x)
        y = pixels.snap(y)
        face = size * 0.42
        middle = y + (size * 0.08)
        line = pixels.whole(size * 0.12)
        [[pen.palette.shadow, alpha * 0.7, line + pixels.line_width(2)], [color, alpha, line]].each do |ink, strength, width|
          pen.color(ink, strength)
          G.line_width = width
          G.circle(:line, x, middle, face, 32)
          G.line(x, middle, x + (face * 0.45), middle - (face * 0.55))
          G.line(x, middle - face, x, middle - face - (size * 0.12))
          G.line(x - (size * 0.14), middle - face - (size * 0.14), x + (size * 0.14), middle - face - (size * 0.14))
        end
      end
    end
  end
end
