# frozen_string_literal: true

module DotPopper
  module Shell
    # A check mark, drawn as two strokes in the gain colour, before a line
    # of text: "✓ Today's goal is done." The font has no check of its own.
    class Check < Data.define(:pen)
      G = ::Lota::Graphics

      # The check and +text+ together, centred on +x+ and +y+.
      def labelled(text, font, x, y, alpha)
        size = font.height
        mark = size * 0.5
        gap = size * 0.25
        left = x - ((mark + gap + font.width(text)) / 2.0)
        draw(left, y, mark, alpha)
        pen.text(text, font, left + mark + gap + (font.width(text) / 2.0), y, pen.palette.gain, alpha)
      end

      private

      # A check +width+ across, from +x+, centred on +y+.
      def draw(x, y, width, alpha)
        pen.color(pen.palette.gain, alpha)
        G.line_width = pen.pixels.whole(width * 0.22)
        G.line(x, y, x + (width * 0.38), y + (width * 0.38), x + width, y - (width * 0.42))
      end
    end
  end
end
