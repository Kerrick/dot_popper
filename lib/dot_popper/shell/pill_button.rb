# frozen_string_literal: true

module DotPopper
  module Shell
    # A button drawn as a pill with its word in it, on whole device
    # pixels: a quiet button, as "Your stats" or the share preview's
    # Close. Its word shrinks, by whole sizes, to fit. +hover+, from 0 to
    # 1, is how lit the mouse over it has made it (Presentation::Hover):
    # its backing and outline brighten. With an +icon+, which draws itself
    # given the middle and the size of a square, the icon and the word
    # stand together in the pill's middle; with an icon and no word, the
    # icon stands alone in its middle.
    class PillButton < Data.define(:pen)
      G = ::Lota::Graphics
      LABEL = Presentation::PillLabel::RATIO # the word's size, in the button's height
      GLYPH = Presentation::PillLabel::GLYPH
      GAP = Presentation::PillLabel::GAP

      def draw(rect, text, alpha: 1.0, color: pen.palette.cream, hover: 0.0, icon: nil, edge: nil)
        return if alpha <= 0.0

        pixels = pen.pixels
        lit = pen.lit
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner = height / 2.0
        fill = pen.palette.pill.mix(lit.fill, hover)
        pen.color(fill, fill.a * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 48)
        pen.color(edge || pen.palette.soft.mix(lit.edge, hover), (edge ? 1.0 : 0.55 + (0.45 * hover)) * alpha)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(x) - x
        G.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 48)
        return word(text, x, y, width, height, color, alpha) unless icon
        return icon.call(x + (width / 2.0), y + (height / 2.0), height) unless text

        beside(text, icon, x, y, width, height, color, alpha)
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

      # The icon and the word side by side, centered together in the pill.
      def beside(text, icon, x, y, width, height, color, alpha)
        mark = height * GLYPH
        gap = height * GAP
        font = fit(text, width - (height * 0.35) - mark - gap, height)
        group = mark + gap + font.width(text)
        left = x + ((width - group) / 2.0)
        icon.call(left + (mark / 2.0), y + (height / 2.0), height)
        pen.text(text, font, left + mark + gap + (font.width(text) / 2.0), y + (height / 2.0), color, alpha)
      end

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
