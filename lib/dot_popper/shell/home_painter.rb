# frozen_string_literal: true

module DotPopper
  module Shell
    # Home, as Presentation::HomeScreen lays it out: the name, the first
    # launch's legend, Play with what it leaves to say under it, today's
    # goal and the days in a row on their card, the four large buttons,
    # and the bottom row. Each large button shows one value.
    class HomePainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        now = show.now
        intro = show.home_entrance.intro(now)
        plan = show.home_plan
        name(show, plan, layout, intro)
        legend(plan, intro) if plan.legend
        hover = show.hover
        PrimaryButton.new(pen:).draw(plan.play, show.play_word, note: show.play_note, alpha: intro, hover: hover.level(:play))
        goal(show, plan.goal, intro) if plan.goal
        plan.tiles.each { |tile, rect| tile(show, tile, rect, intro) }
        plan.pills.each { |pill, rect| pill(show, pill, rect, intro) }
        quit_prompt(show, plan)
      end

      private

      def name(show, plan, layout, alpha)
        rect = plan.name
        words = show.words
        if pen.art then ThemedName.new(pen:, dots:).draw(words.game_name, rect.center_x, rect.center_y, plan.name_size, alpha, room: rect.width)
        else Lettering.new(pen:).candy(words.game_name, pen.fonts.bold(plan.name_size), rect.center_x, rect.center_y, alpha)
        end
      end

      # A bright dot, then "+1" and "+1" with a stopwatch; under it a
      # popped dot, then "−2" and "−2" with a stopwatch.
      def legend(plan, alpha)
        font = pen.fonts.bold(plan.legend_size)
        legend = Presentation::Legend.measure(font.height) { font.width(it) }
        radius = legend.radius
        x = plan.legend.center_x - (legend.width / 2.0)
        y = plan.legend.center_y
        tallies = TallyPainter.new(pen:)
        Presentation::Legend.rows.each_with_index do |(bright, points, seconds), i|
          row = y + ((i - 0.5) * radius * Presentation::Legend::ROW)
          dots.icon(x + radius, row, radius, bright:, opacity: alpha)
          tallies.left(points, font, x + legend.points, row, bright ? pen.palette.cream : pen.palette.alarm, alpha)
          tallies.left(seconds, font, x + legend.seconds, row, bright ? pen.palette.gain : pen.palette.alarm, alpha)
        end
      end

      def goal(show, rect, alpha)
        palette = pen.palette
        Card.new(pen:).draw(rect, alpha:)
        card = Presentation::GoalCard.fit(rect, show.words.goal_sentence(show.stats_book.goal), FontMeasure.new(pen.fonts))
        pad = card.pad
        divider = card.divider
        label = pen.fonts.semibold(card.label_size)
        text = pen.fonts.bold(card.text_size)
        done = show.stats_book.goal_done?
        tone = done ? palette.gain : palette.soft
        heading = show.words.goal_card_label
        pen.text(heading, label, rect.x + pad + (label.width(heading) / 2.0), rect.y + pad + (label.height / 2.0), tone, alpha)
        Glyphs.new(pen:).draw(:check, rect.x + pad + label.width(heading) + (label.height * 0.9), rect.y + pad + (label.height / 2.0), label.height * 0.9, color: palette.gain, alpha:) if done
        card.lines.each_with_index do |line, i|
          pen.text(line, text, rect.x + pad + (text.width(line) / 2.0), card.top + (text.height * (i + 0.5)), done ? palette.gain : palette.cream, alpha)
        end
        pen.color(palette.soft, 0.25 * alpha)
        G.line_width = pen.pixels.line_width(1)
        G.line(pen.pixels.snap(divider), rect.y + pad, pen.pixels.snap(divider), rect.bottom - pad)
        streak(show, rect, divider, label, alpha)
      end

      def streak(show, rect, divider, label, alpha)
        palette = pen.palette
        x = (divider + rect.right) / 2.0
        digits = pen.fonts.bold([(rect.height * 0.32).round, 16].max)
        days = show.stats_book.streak
        top = rect.y + (rect.height * 0.3)
        Lettering.new(pen:).candy(days.to_s, digits, x, top, alpha, face: palette.bright_body, side: palette.bright_deep)
        pen.text(show.words.streak_days(days), label, x, top + (digits.height * 0.72), palette.soft, alpha)
        pen.text(show.words.streak_in_a_row, label, x, top + (digits.height * 0.72) + label.height, palette.soft, alpha)
      end

      # A large button: its icon, its name, one value, and on a controller
      # its button in the corner.
      def tile(show, tile, rect, alpha)
        palette = pen.palette
        Card.new(pen:).draw(rect, alpha:, lit: show.hover.level(tile))
        size = [rect.height * 0.46, 20.0].max
        icon_x = rect.x + (rect.height * 0.32) + (size * 0.3)
        text_x = icon_x + (size * 0.72) + 8
        icon(show, tile, icon_x, rect.center_y, size, alpha)
        room = rect.right - text_x - 8
        heading = fit_bold(show.tile_word(tile), [(rect.height * 0.23).round, 18].min, room)
        note = fit(show.tile_note(tile), [(rect.height * 0.18).round, 16].min, room)
        pen.text(show.tile_word(tile), heading, text_x + (heading.width(show.tile_word(tile)) / 2.0), rect.center_y - (note.height * 0.5), palette.cream, alpha)
        pen.text(show.tile_note(tile), note, text_x + (note.width(show.tile_note(tile)) / 2.0), rect.center_y + (heading.height * 0.55), palette.soft, alpha)
        badge(show, tile, rect, alpha) if show.input == Presentation::InputKind::GAMEPAD
      end

      def icon(show, tile, x, y, size, alpha)
        case tile
        when :themes then dots.icon(x, y, size * 0.6, bright: true, opacity: alpha)
        else Glyphs.new(pen:).draw({ stats: :bars, achievements: :ribbon, groups: :crown }.fetch(tile), x, y, size, color: pen.palette.bright_body, alpha:, weight: 1.8)
        end
      end

      def badge(show, tile, rect, alpha)
        text = show.words.tile_badge(tile)
        font = pen.fonts.semibold(13)
        width = font.width(text) + 14
        height = font.height + 4
        x = rect.right - width - 8
        y = rect.y - (height / 2.0)
        pen.color(pen.palette.ink_top, alpha)
        G.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 12)
        pen.color(pen.palette.soft, 0.5 * alpha)
        G.rectangle(:line, x, y, width, height, height / 2.0, height / 2.0, 12)
        pen.text(text, font, x + (width / 2.0), y + (height / 2.0), pen.palette.soft, alpha)
      end

      def pill(show, name, rect, alpha)
        glyph = { how_to_play: :question, settings: :gear, quit: :power }.fetch(name)
        PillButton.new(pen:).draw(rect, show.words.public_send(name), alpha:, hover: show.hover.level(name),
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(glyph, x, y, size * 0.42, alpha:) })
      end

      def fit(text, size, room)
        size -= 1 while size > 11 && pen.fonts.semibold(size).width(text) > room
        pen.fonts.semibold(size)
      end

      def fit_bold(text, size, room)
        size -= 1 while size > 11 && pen.fonts.bold(size).width(text) > room
        pen.fonts.bold(size)
      end

      # "Press B again to quit", above the bottom row, while a second B
      # would quit.
      def quit_prompt(show, plan)
        alpha = show.quit_prompt
        return unless alpha.positive?

        x, y = plan.quit_line
        font = pen.fonts.semibold(18)
        pen.text(show.words.quit_again, font, x, y, pen.palette.cream, alpha)
      end
    end
  end
end
