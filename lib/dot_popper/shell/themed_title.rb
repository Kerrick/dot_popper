# frozen_string_literal: true

module DotPopper
  module Shell
    # The name on the title, as a theme sets it: in its own font when it
    # has one, with its O's drawn as the theme's own bright dots; or, for
    # Eclipse, set beside a small crescent. A theme without art keeps the
    # ordinary candy lettering.
    class ThemedTitle < Data.define(:pen, :dots)
      DOT_RADIUS = 0.6  # an O's radius, in the cap height

      def draw(text, center_x, center_y, size, alpha, room: nil)
        art = pen.art
        font = pen.fonts.face(art.wordmark || pen.style::TYPE.bold, size)
        word = art.wordmark && art.title_dots ? text.upcase : text
        return crescent_title(word, art, center_x, center_y, size, alpha, room) unless art.title_dots

        spread = widths(word, font).sum
        font = pen.fonts.face(art.wordmark || pen.style::TYPE.bold, (size * room / spread).floor) if room && spread > room
        letters(word, font, center_x, center_y, alpha)
      end

      private

      def letters(word, font, center_x, center_y, alpha)
        radius = font.height * 0.78 * DOT_RADIUS
        spans = widths(word, font)
        x = center_x - (spans.sum / 2.0)
        word.each_char.with_index do |char, i|
          mid = x + (spans[i] / 2.0)
          if %w[O o].include?(char)
            dots.icon(mid, center_y, radius, bright: true, opacity: alpha)
          else
            pen.text(char, font, mid, center_y, pen.palette.bright_body, alpha)
          end
          x += spans[i]
        end
      end

      def span(word, font) = (font.height * 0.84) + (font.height * 0.19) + font.width(word)

      def widths(word, font)
        cap = font.height * 0.78
        word.chars.map { %w[O o].include?(it) ? (cap * DOT_RADIUS * 2) + (cap * 0.08) : font.width(it) }
      end

      # The name beside a small crescent, the two centered as one.
      def crescent_title(word, art, center_x, center_y, size, alpha, room)
        font = pen.fonts.face(art.wordmark, size)
        font = pen.fonts.face(art.wordmark, (size * room / span(word, font)).floor) if room && span(word, font) > room
        r = font.height * 0.42
        gap = r * 0.45
        total = span(word, font)
        left = center_x - (total / 2.0)
        dots.icon(left + r, center_y, r, bright: true, opacity: alpha)
        dots.icon(left + r + (r * 0.3), center_y - (r * 0.22), r * 0.92, bright: false, opacity: alpha)
        pen.text(word, font, left + (r * 2) + gap + (font.width(word) / 2.0), center_y, pen.palette.cream, alpha)
      end
    end
  end
end
