# frozen_string_literal: true

module DotPopper
  module Shell
    # The title screen: the name, a legend that teaches the rule with one
    # dot of each kind, the best score, the prompt, the mute button, and,
    # once a round has been played, today's goal, "Your records", and,
    # where it changes something, the choice of how dots are sized. From the name to the prompt, the words
    # sit on a faint backing, so the dots drifting behind them dim further.
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
        goal = show.records_offered?
        prompt = pen.fonts.bold(layout.scaled(type.prompt))
        prompt_y = center + (height * (goal ? 0.29 : 0.27))
        backing(layout, title, show.words, center - (height * 0.2) - (title.height * 0.4),
                prompt_y + (prompt.height * 0.5), intro)
        Lettering.new(pen:).candy(show.words.title, title, layout.center_x, center - (height * 0.2) - ((1 - intro) * 24),
                                  intro)
        legend(show, layout, center + (height * 0.02), intro)
        best = pen.fonts.semibold(layout.scaled(type.best))
        if marquee.best.positive?
          pen.text(show.words.best_line(marquee.best), best, layout.center_x, center + (height * (goal ? 0.125 : 0.14)),
                    pen.palette.soft, intro)
        end
        daily_goal(show, layout, center + (height * 0.195), intro) if goal
        pen.text(show.words.play, prompt, layout.center_x, prompt_y, pen.palette.cream, intro * marquee.prompt(now))
        MuteButton.new(pen:).draw(layout.mute_button, show.sounds.muted?)
        return unless show.records_offered?

        PillButton.new(pen:).draw(layout.records_button, show.words.records, alpha: intro)
        sizing_choice(show, layout.sizing_control, intro) if show.sizing_offered?
      end

      private

      # The choice of dot size, each segment named by what it does here
      # and showing a dot at the size it gives, in true proportion.
      def sizing_choice(show, control, alpha)
        preview = show.sizing_preview
        height = control.options.first.height
        choices = Presentation::Show::SIZINGS.map do
          [show.words.sizing(it, preview), it == show.game.sizing, preview.icon(it, height)]
        end
        SegmentedPainter.new(pen:, dots:).draw(control, show.words.sizing_label, choices, alpha:)
      end

      # The backing from +top+ to +bottom+, as wide as the name or the
      # legend, whichever is wider.
      def backing(layout, title, words, top, bottom, alpha)
        font = legend_font(legend_items(words), layout)
        width = [title.width(words.title), legend_width(legend_items(words), font)].max
        rect = Presentation::Rect.new(x: layout.center_x - (width / 2.0), y: top, width:, height: bottom - top)
        ScrimPainter.new(pen:).draw(rect, pen.look::TITLE_BACKING, layout, alpha:)
      end

      def legend_items(words) = [[true, words.legend_fresh], [false, words.legend_popped]]

      # How wide the legend is in +font+: a dot, a gap, and its longer line.
      def legend_width(items, font)
        radius = font.height * 0.5
        items.map { |_, text| (radius * 2.7) + font.width(text) }.max
      end

      # Today's goal, broken into lines that fit across, or once it is met,
      # "Today's goal is done." with a check; under it, the days in a row
      # it has been met, from two days on. Centred on +y+.
      def daily_goal(show, layout, y, alpha)
        words = show.words
        lifetime = show.lifetime
        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.summary * 1.1))
        room = layout.safe.width - (layout.margin * 4)
        lines = if lifetime.goal_done? then [words.goal_done]
                else Presentation::Words.balance(words.goal(lifetime.goal), room) { font.width(it) }
                end
        step = font.height * 1.2
        streak = lifetime.streak
        streak_line = words.streak(streak) if streak >= 2
        # The streak is a line apart, half a line below the goal's.
        lines_y = lines.each_index.map { it * step }
        lines_y << (lines_y.last + (step * 1.5)) if streak_line
        top = y - (lines_y.last / 2.0)
        (lines + [streak_line].compact).zip(lines_y).each_with_index do |(line, dy), i|
          if lifetime.goal_done? && i.zero? then Check.new(pen:).labelled(line, font, layout.center_x, top, alpha)
          else pen.text(line, font, layout.center_x, top + dy, pen.palette.soft, alpha)
          end
        end
      end

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
        items = legend_items(show.words)
        font = legend_font(items, layout)
        radius = font.height * 0.5
        gap = radius * 0.7
        width = legend_width(items, font)
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
