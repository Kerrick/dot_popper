# frozen_string_literal: true

module DotPopper
  module Shell
    # The box a code being tapped shows in, a bit darker than a button.
    class CodeBox < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(rect, text, font, empty:)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner = height / 3.0
        pen.color(pen.palette.ink_bottom, 0.85)
        G.rectangle(:fill, x, y, width, height, corner, corner, 24)
        pen.color(pen.palette.soft, 0.6)
        G.line_width = pixels.line_width(1)
        G.rectangle(:line, x, y, width, height, corner, corner, 24)
        pen.text(text, font, rect.center_x, rect.center_y, empty ? pen.palette.soft : pen.palette.cream)
      end
    end
  end
end
