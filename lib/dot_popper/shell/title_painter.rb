# frozen_string_literal: true

module DotPopper
  module Shell
    # The title screen: the name, a legend that teaches the rule with one
    # dot of each kind, the best score, the prompt, and the Daily and mute
    # buttons.
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
        PillButton.new(pen:).draw(layout.daily_button(2 * show.game.field.radius), show.words.daily_label(show.today),
                                  alpha: intro)
      end

      private

      # The title's size, shrunk if the name would not fit across.
      def fit(size, text, layout)
        width = pen.fonts.bold(size).width(text)
        room = layout.safe.width - (layout.margin * 4)
        width > room ? (size * room / width).floor : size
      end

      # "+1 · +1s" beside a fresh dot and "−2 · −2s" beside a popped one:
      # side by side, or one above the other on a narrow screen.
      def legend(show, layout, y, alpha)
        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.legend))
        radius = font.height * 0.5
        gap = radius * 0.7
        items = [[true, "#{Presentation::Words.points(Rules::POP_POINTS)} · #{Presentation::Words.seconds(Rules::POP_SECONDS)}"],
                 [false, "#{Presentation::Words.points(-Rules::PENALTY_POINTS)} · #{Presentation::Words.seconds(-Rules::PENALTY_SECONDS)}"]]
        widths = items.map { |_, text| (radius * 2) + gap + font.width(text) }
        spacing = radius * 2.4
        if widths.sum + spacing <= layout.safe.width - (layout.margin * 2)
          x = layout.center_x - ((widths.sum + spacing) / 2.0)
          items.each_with_index do |(fresh, text), i|
            item(x, y, radius, gap, fresh, text, font, alpha)
            x += widths[i] + spacing
          end
        else
          items.each_with_index do |(fresh, text), i|
            item(layout.center_x - (widths[i] / 2.0), y + ((i - 0.5) * radius * 2.8), radius, gap, fresh, text, font, alpha)
          end
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
