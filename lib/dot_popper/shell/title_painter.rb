# frozen_string_literal: true

module DotPopper
  module Shell
    # The title screen: the name, a legend that teaches the rule with one
    # dot of each kind, the best score, the Play button, "How to play",
    # the mute button, and, once a round has been played, today's goal,
    # "Your records", and, where it changes something, the choice of how
    # dots are sized, each where the Show's TitlePlan puts it. From the name to the prompt, the
    # words sit on a faint backing, so the dots drifting behind them dim
    # further.
    class TitlePainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics
      HELP = 0.3 # the help sign's ring's radius, in the button's height
      HELP_MARK = 0.42 # its question mark's size, in the button's height
      HELP_LINE = 0.035 # its ring's width, in the button's height, at least a device pixel

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
        legend(layout, plan, under_quit(show, plan, :legend, intro))
        line(plan, :best, words.best_line(marquee.best), pen.palette.soft, under_quit(show, plan, :best, intro))
        daily_goal(show, layout, plan, under_quit(show, plan, :goal, intro)) if plan[:goal]
        quit_prompt(show, plan)
        line(plan, :streak, words.streak(show.lifetime.streak), pen.palette.soft, intro, size: :goal)
        hover = show.hover
        PrimaryButton.new(pen:).draw(plan.play_button, words.play, alpha: intro, hover: hover.level(:play))
        MuteButton.new(pen:).draw(plan.mute_button, show.sounds.muted?, hover: hover.level(:mute))
        PillButton.new(pen:).draw(plan.how_to_play_button, words.how_to_play, alpha: intro,
                                  hover: hover.level(:how_to_play),
                                  icon: ->(x, y, size) { help(x, y, size, intro) })
        return unless show.records_offered?

        PillButton.new(pen:).draw(plan.records_button, words.records, alpha: intro, hover: hover.level(:records))
        sizing_choice(show, plan.sizing_control, intro) if show.sizing_offered?
      end

      private

      # "How to play"'s icon: the help sign, a question mark in a thin
      # ring, in a square +size+ across around +x+, +y+, the same for every
      # input. The ring and the mark sit on whole device pixels.
      def help(x, y, size, alpha)
        pixels = pen.pixels
        width = [(size * HELP_LINE * pixels.scale).round, 1].max
        pen.color(pen.palette.cream, alpha)
        G.line_width = pixels.line_width(width)
        G.circle(:line, pixels.line_at(x, width), pixels.line_at(y, width), pixels.snap(size * HELP), 48)
        mark = pen.fonts.semibold(Presentation::Pixels.font_size(size * HELP_MARK))
        pen.text("?", mark, x, y, pen.palette.cream, alpha)
      end

      # The choice of dot size, each segment named, saying what it does
      # here, and showing a dot at the size it gives, in true proportion.
      def sizing_choice(show, control, alpha)
        preview = show.sizing_preview
        words = show.words
        height = control.options.first.height
        choices = Presentation::Show::SIZINGS.map do
          [words.sizing(it, preview), words.sizing_note(it, preview), it == show.game.sizing, preview.icon(it, height),
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

      # How much of the line +name+ shows, +alpha+ of it, less as "Press B
      # again to quit" shows in its place, where the plan puts it there.
      def under_quit(show, plan, name, alpha) = plan.quit_over == name ? alpha * (1 - show.quit_prompt) : alpha

      # "Press B again to quit", where the plan puts it, while a second B
      # would quit.
      def quit_prompt(show, plan)
        alpha = show.quit_prompt
        return unless alpha.positive?

        rect = plan.quit_line
        pen.text(show.words.quit_again, pen.fonts.semibold(plan.size(:goal)), rect.center_x, rect.center_y,
                 pen.palette.cream, alpha)
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

      # A bright dot, then "+1" and "+1" with a stopwatch, and beneath it a
      # popped dot, then "−2" and "−2" with a stopwatch, in the colours the
      # Tutorial flies them in (Presentation::Legend).
      def legend(layout, plan, alpha)
        font = pen.fonts.bold(plan.size(:legend))
        legend = Presentation::Legend.measure(font.height) { font.width(it) }
        radius = legend.radius
        x = layout.center_x - (legend.width / 2.0)
        y = plan[:legend].center_y
        tallies = TallyPainter.new(pen:)
        Presentation::Legend.rows.each_with_index do |(fresh, points, seconds), i|
          row = y + ((i - 0.5) * radius * Presentation::Legend::ROW)
          dots.icon(x + radius, row, radius, fresh:, opacity: alpha)
          tallies.left(points, font, x + legend.points, row, fresh ? pen.palette.cream : pen.palette.alarm, alpha)
          tallies.left(seconds, font, x + legend.seconds, row, fresh ? pen.palette.gain : pen.palette.alarm, alpha)
        end
      end
    end
  end
end
