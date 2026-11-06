# frozen_string_literal: true

module DotPopper
  module Shell
    # The title screen: the name, a legend that teaches the rule with one
    # dot of each kind, the best score, the Play button, the mute button, and,
    # once a round has been played, today's goal, "Your records", and,
    # where it changes something, the choice of how dots are sized, each
    # where the Show's TitlePlan puts it. From the name to the prompt, the
    # words sit on a faint backing, so the dots drifting behind them dim
    # further.
    class TitlePainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        now = show.now
        marquee = show.marquee
        intro = marquee.intro(now)
        words = show.words
        plan = show.title_plan
        ScrimPainter.new(pen:).draw(plan.backing, pen.look::TITLE_BACKING, layout, alpha: intro)
        title = pen.fonts.bold(plan.size(:title))
        Lettering.new(pen:).candy(words.title, title, layout.center_x,
                                  plan[:title].y + (title.height / 2.0) - ((1 - intro) * 24), intro)
        legend(show, layout, plan, intro)
        line(plan, :best, words.best_line(marquee.best), pen.palette.soft, intro)
        daily_goal(show, layout, plan, intro) if plan[:goal]
        line(plan, :streak, words.streak(show.lifetime.streak), pen.palette.soft, intro, size: :goal)
        hover = show.hover
        PrimaryButton.new(pen:).draw(plan.play_button, words.play, alpha: intro, hover: hover.level(:play))
        MuteButton.new(pen:).draw(plan.mute_button, show.sounds.muted?, hover: hover.level(:mute))
        return unless show.records_offered?

        PillButton.new(pen:).draw(plan.records_button, words.records, alpha: intro, hover: hover.level(:records))
        sizing_choice(show, plan.sizing_control, intro) if show.sizing_offered?
      end

      private

      # The choice of dot size, each segment named, saying what it does
      # here, and showing a dot at the size it gives, in true proportion.
      def sizing_choice(show, control, alpha)
        preview = show.sizing_preview
        words = show.words
        height = control.options.first.height
        choices = Presentation::Show::SIZINGS.map do
          [words.sizing(it), words.sizing_note(it, preview), it == show.game.sizing, preview.icon(it, height),
           show.hover.level(it)]
        end
        SegmentedPainter.new(pen:, dots:).draw(control, show.words.sizing_label, choices, alpha:)
      end

      # A line of +text+ in its place in +plan+, if it has one, in the
      # semibold size the plan gives +size+.
      def line(plan, name, text, color, alpha, size: name)
        rect = plan[name] or return

        pen.text(text, pen.fonts.semibold(plan.size(size)), rect.center_x, rect.center_y, color, alpha)
      end

      # Today's goal in the lines the plan broke it into; once it is met,
      # the same goal, "Done today: ...", with a check before its first
      # line.
      def daily_goal(show, layout, plan, alpha)
        font = pen.fonts.semibold(plan.size(:goal))
        top = plan[:goal].y + (font.height / 2.0)
        plan.goal_lines.each_with_index do |line, i|
          y = top + (font.height * 1.2 * i)
          if show.lifetime.goal_done? && i.zero?
            Check.new(pen:).labelled(line, font, layout.center_x, y, alpha)
          else
            pen.text(line, font, layout.center_x, y, pen.palette.soft, alpha)
          end
        end
      end

      # "Tap a bright dot: +1 point, +1 second" beside a fresh dot, and the
      # popped dot's line beneath it, the two lines left-aligned on their
      # dots so they read as a pair.
      def legend(show, layout, plan, alpha)
        words = show.words
        items = [[true, words.legend_fresh], [false, words.legend_popped]]
        font = pen.fonts.semibold(plan.size(:legend))
        radius = font.height * 0.5
        gap = radius * 0.7
        width = items.map { |_, text| (radius * 2.7) + font.width(text) }.max
        x = layout.center_x - (width / 2.0)
        y = plan[:legend].center_y
        items.each_with_index do |(fresh, text), i|
          item(x, y + ((i - 0.5) * radius * 2.8), radius, gap, fresh, text, font, alpha)
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
