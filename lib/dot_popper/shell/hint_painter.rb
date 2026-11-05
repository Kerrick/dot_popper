# frozen_string_literal: true

module DotPopper
  module Shell
    # The first-run hint, just under the HUD: its sentences on one line
    # when they fit across the safe area, one above the other when not.
    # It never shakes, and a tap goes through it to the dots beneath.
    class HintPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(hint, now, layout, below)
        alpha = hint.alpha(now)
        return if alpha <= 0.0

        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.hint))
        lines = fit(hint.lines, font, layout)
        pad = font.height * 0.45
        width = lines.map { font.width(it) }.max + (pad * 2.6)
        height = (font.height * lines.size) + (pad * 1.2)
        top = below + (layout.margin * 0.6)
        backing(layout.center_x - (width / 2.0), top, width, height, alpha)
        lines.each_with_index do |line, i|
          pen.text(line, font, layout.center_x, top + (pad * 0.6) + (font.height * (i + 0.5)), pen.palette.cream, alpha)
        end
      end

      private

      def fit(lines, font, layout)
        joined = lines.join(" ")
        font.width(joined) <= layout.safe.width - (layout.margin * 4) ? [joined] : lines
      end

      def backing(x, y, width, height, alpha)
        pixels = pen.pixels
        x, y, width, height = [x, y, width, height].map { pixels.snap(it) }
        corner = [height / 2.0, pixels.snap(22)].min
        pen.color(pen.palette.pill, pen.palette.pill.a * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 32)
      end
    end
  end
end
