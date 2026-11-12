# frozen_string_literal: true

module DotPopper
  module Shell
    # The gamepad cursor's reticle, over everything: a thin cream ring
    # with four ticks and a pip at its center, each on a dark edge so it
    # reads over a light dot or the night. Its center and strokes sit on
    # whole device pixels; the press lands where the cursor really is.
    class CursorPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(cursor)
        return unless cursor.visible

        style = pen.style::GAMEPAD
        pixels = pen.pixels
        line = [(style.line * cursor.radius * pixels.scale).round, 1].max
        x = pixels.line_at(cursor.x, line)
        y = pixels.line_at(cursor.y, line)
        [[pen.palette.shadow, 0.75, line + 2], [pen.palette.cream, 1.0, line]].each do |color, alpha, width|
          pen.color(color, alpha)
          reticle(x, y, width, style.pip + width - line, cursor.radius, style)
        end
      end

      private

      def reticle(x, y, width, pip, radius, style)
        pixels = pen.pixels
        G.line_width = pixels.line_width(width)
        G.circle(:line, x, y, style.ring * radius, 48)
        from = pixels.snap(style.ticks.begin * radius)
        to = pixels.snap(style.ticks.end * radius)
        [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          G.line(x + (dx * from), y + (dy * from), x + (dx * to), y + (dy * to))
        end
        G.circle(:fill, x, y, pip / 2.0 / pixels.scale, 16)
      end
    end
  end
end
