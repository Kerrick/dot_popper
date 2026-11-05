# frozen_string_literal: true

module DotPopper
  module Shell
    # The title screen: the name, a legend that teaches the rule with one
    # dot of each kind, the best score, the prompt, the mute button, and,
    # once a round has been played, "Your records".
    class TitlePainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        now = show.now
        marquee = show.marquee
        intro = marquee.intro(now)
        type = pen.look::TYPE
        height = layout.safe.height
        center = layout.center_y
        title = pen.fonts.bold(fit(layout.scaled(type.title), show.words.title, layout))
        Lettering.new(pen:).candy(show.words.title, title, layout.center_x, center - (height * 0.2) - ((1 - intro) * 24),
                                  intro)
        legend(show, layout, center + (height * 0.02), intro)
        best = pen.fonts.semibold(layout.scaled(type.best))
        if marquee.best.positive?
          pen.text(show.words.best_line(marquee.best), best, layout.center_x, center + (height * 0.14),
                    pen.palette.soft, intro)
        end
        prompt = pen.fonts.bold(layout.scaled(type.prompt))
        pen.text(show.words.play, prompt, layout.center_x, center + (height * 0.27), pen.palette.cream,
                  intro * marquee.prompt(now))
        MuteButton.new(pen:).draw(layout.mute_button, show.sounds.muted?)
        PillButton.new(pen:).draw(layout.records_button, show.words.records, alpha: intro) if show.records_offered?
      end

      private

      # The title's size, shrunk if the name would not fit across.
      def fit(size, text, layout)
        width = pen.fonts.bold(size).width(text)
        room = layout.safe.width - (layout.margin * 4)
        width > room ? (size * room / width).floor : size
      end

      # "Tap a bright dot: +1 point, +1 second" beside a fresh dot, and the
      # popped dot's line beneath it, the two lines left-aligned on their
      # dots so they read as a pair.
      def legend(show, layout, y, alpha)
        words = show.words
        items = [[true, words.legend_fresh], [false, words.legend_popped]]
        font = legend_font(items, layout)
        radius = font.height * 0.5
        gap = radius * 0.7
        width = items.map { |_, text| (radius * 2) + gap + font.width(text) }.max
        x = layout.center_x - (width / 2.0)
        items.each_with_index do |(fresh, text), i|
          item(x, y + ((i - 0.5) * radius * 2.8), radius, gap, fresh, text, font, alpha)
        end
      end

      # The legend's size, shrunk to whole sizes until its longer line fits.
      def legend_font(items, layout)
        size = layout.scaled(pen.look::TYPE.legend)
        room = layout.safe.width - (layout.margin * 2)
        loop do
          font = pen.fonts.semibold(size)
          widest = items.map { |_, text| (font.height * 1.7) + font.width(text) }.max
          return font if widest <= room || size <= 12

          size -= 1
        end
      end

      def item(x, y, radius, gap, fresh, text, font, alpha)
        dots.icon(x + radius, y, radius, fresh:, opacity: alpha)
        width = font.width(text)
        pen.text(text, font, x + (radius * 2) + gap + (width / 2.0), y, fresh ? pen.palette.cream : pen.palette.soft, alpha)
      end
    end
  end
end
