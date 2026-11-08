# frozen_string_literal: true

module DotPopper
  module Shell
    # A button drawn as a pill with its word in it, on whole device
    # pixels: a quiet button, as "Your records" or the share preview's
    # Close. Its word shrinks, by whole sizes, to fit. +hover+, from 0 to
    # 1, is how lit the mouse over it has made it (Presentation::Hover):
    # its backing and outline brighten. With an +icon+, which draws itself
    # given the middle and the size of a square, the icon stands at the
    # pill's left end and the word in the room to its right.
    class PillButton < Data.define(:pen)
      G = ::Lota::Graphics
      LABEL = 0.4 # the word's size, in the button's height
      ICON = 1.1 # the room an icon takes, in the button's height

      def draw(rect, text, alpha: 1.0, color: pen.palette.cream, hover: 0.0, icon: nil)
        return if alpha <= 0.0

        pixels = pen.pixels
        lit = pen.look::HOVER
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner = height / 2.0
        fill = pen.palette.pill.mix(lit.fill, hover)
        pen.color(fill, fill.a * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 48)
        pen.color(pen.palette.soft.mix(lit.edge, hover), (0.55 + (0.45 * hover)) * alpha)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(x) - x
        G.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 48)
        return word(text, x, y, width, height, color, alpha) unless icon

        icon.call(x + (height * ICON / 2.0), y + (height / 2.0), height)
        beside = height * ICON * 0.85
        word(text, x + beside, y, width - beside, height, color, alpha)
      end

      # Only the words of a pill already drawn, on top of whatever has
      # since been drawn over it, in the same place and size.
      def label(rect, text, alpha: 1.0, color: pen.palette.cream)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        font = fit(text, width - (height * 0.6), height)
        pen.text(text, font, x + (width / 2.0), y + (height / 2.0), color, alpha)
      end

      private

      def word(text, x, y, width, height, color, alpha)
        font = fit(text, width - (height * 0.6), height)
        pen.text(text, font, x + (width / 2.0), y + (height / 2.0), color, alpha)
      end

      def fit(text, room, height)
        size = (height * LABEL).round
        size -= 1 while size > 10 && pen.fonts.semibold(size).width(text) > room
        pen.fonts.semibold(size)
      end
    end
  end
end
