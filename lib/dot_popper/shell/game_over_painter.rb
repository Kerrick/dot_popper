# frozen_string_literal: true

module DotPopper
  module Shell
    # Game Over, over the finished game, each part where the Show's
    # GameOverPlan puts it: "Time's up!", the score counting up, a new
    # record or how far short of the score record it fell, a quiet line of the
    # game's facts, a record it set, its lines in pills (today's
    # goal met, a new achievement, a friend group's title), those that open
    # something with an arrow, then Play again, faint until a press will
    # be heard, and Home beside Share my score, all over the dimmed pile,
    # as the mocks draw it, with no backing of their own. The stacking
    # rule is taught on the pile itself, with no word (Show#replay_mistake).
    class GameOverPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        game_over = show.game_over or return
        plan = show.game_over_plan
        now = show.now
        palette = pen.palette
        words = show.words
        arrival = game_over.arrival(now)
        shown = arrival.clamp(0.0, 1.0)
        if (heading = plan[:heading])
          pen.text(words.time_up, pen.fonts.bold(plan.size(:heading)), heading.center_x,
                   heading.center_y - ((1 - arrival) * 30), palette.soft, shown)
        end
        score = pen.fonts.bold(plan.size(:score))
        Lettering.new(pen:).candy(game_over.shown_score(now).to_s, score, plan[:score].center_x,
                                  plan[:score].y + (score.height / 2.0), shown)
        score_record_line(show, plan, now, shown)
        facts(show, plan, shown)
        line(plan, :record, words.record(game_over.record), palette.gain, game_over.afterword(now)) if game_over.record && game_over.counted?(now)
        chips(show, plan, game_over.afterword(now)) if game_over.counted?(now)
        buttons(show, plan, game_over, now, shown, layout)
      end

      private

      def buttons(show, plan, game_over, now, shown, layout)
        words = show.words
        if (home = plan.home_button)
          PillButton.new(pen:).draw(home, words.button(:home), alpha: shown, hover: show.hover.level(:home),
                                    icon: ->(x, y, size) { Glyphs.new(pen:).draw(:home, x, y, size * 0.42, alpha: shown) })
        end
        if (button = plan.share_button)
          ShareButton.new(pen:).draw(button, words.share, entrance: game_over.share_button_entrance(now), ui: layout.ui, hover: show.hover.level(:share))
        end
        play = plan.play_button or return
        PrimaryButton.new(pen:).draw(play, show.game_over_screen.play_word, alpha: [shown * 0.35, game_over.prompt(now)].max,
                                     hover: show.hover.level(:play_again), note: show.game_over_screen.play_note)
      end

      # Each of the game's lines in a pill: its mark, its words, and an
      # arrow where a press opens what it names.
      def chips(show, plan, alpha)
        return unless alpha.positive?

        font = pen.fonts.semibold(plan.size(:chip))
        show.game_over_chips.each_with_index do |chip, i|
          rect = plan[[:chip, i]] or next
          hover = chip.opens ? show.hover.level(chip.name) : 0.0
          Card.new(pen:).draw(rect, corner: rect.height / 2.0, alpha:, lit: hover)
          mark = rect.height * 0.42
          room = rect.width - (rect.height * (chip.opens ? 1.9 : 1.4))
          text = font.width(chip.text) > room ? fitted(chip.text, font, room) : chip.text
          left = rect.x + (rect.height * 0.5)
          glyph(chip, left + (mark / 2.0), rect.center_y, mark, alpha)
          pen.text(text, font, left + mark + (rect.height * 0.22) + (font.width(text) / 2.0), rect.center_y, pen.palette.cream, alpha)
          Glyphs.new(pen:).draw(:chevron_right, rect.right - (rect.height * 0.45), rect.center_y, mark * 0.7, alpha:) if chip.opens
        end
      end

      def glyph(chip, x, y, size, alpha)
        case chip.glyph
        when :check then Glyphs.new(pen:).draw(:check, x, y, size, color: pen.palette.gain, alpha:, weight: 2.2)
        when :achievement then Glyphs.new(pen:).draw(:ribbon, x, y, size, color: pen.palette.bright_body, alpha:)
        else Glyphs.new(pen:).draw(:crown, x, y, size, color: pen.palette.bright_body, alpha:)
        end
      end

      # +text+ cut short with an ellipsis to fit +room+.
      def fitted(text, font, room)
        cut = text
        cut = cut[0...-1] while cut.size > 1 && font.width("#{cut}…") > room
        "#{cut.rstrip}…"
      end

      # The game's facts, each its sign and its number: a bright dot, a
      # popped one, and the game's stopwatch (TallyPainter), in a row or one
      # under another, as the plan put them.
      def facts(show, plan, alpha)
        list = Presentation::Words.facts(show.game_over.stats)
        font = pen.fonts.bold(plan.size(:facts))
        screen = Presentation::GameOverScreen
        if (row = plan[:summary])
          x = row.x
          list.each { |sign, text| x = fact(sign, text, font, x, row.center_y, alpha) + (font.height * screen::FACTS_APART) }
        else
          list.each_with_index { |(sign, text), i| (rect = plan[[:fact, i]]) && fact(sign, text, font, rect.x, rect.center_y, alpha) }
        end
      end

      # One fact from +x+, its middle at +y+; where it ends.
      def fact(sign, text, font, x, y, alpha)
        screen = Presentation::GameOverScreen
        size = font.height * screen::FACT_SIGN
        middle = x + (size / 2.0)
        case sign
        when :stopwatch then TallyPainter.new(pen:).stopwatch(middle, y, size, pen.palette.cream, alpha)
        else dots.icon(middle, y, size * 0.5, bright: sign == :bright, opacity: alpha)
        end
        left = x + (font.height * (screen::FACT_SIGN + screen::FACT_GAP))
        pen.text(text, font, left + (font.width(text) / 2.0), y, pen.palette.cream, alpha)
        left + font.width(text)
      end

      # A semibold line of +text+ in its place in +plan+, if it has one.
      def line(plan, name, text, color, alpha)
        rect = plan[name] or return

        pen.text(text, pen.fonts.semibold(plan.size(:summary)), rect.center_x, rect.center_y, color, alpha)
      end

      # A new record, glowing, once the score has counted up, or how far
      # short of the score record the game fell.
      def score_record_line(show, plan, now, alpha)
        rect = plan[:score_record] or return
        game_over = show.game_over
        return if game_over.new_score_record? && !game_over.counted?(now)

        face, size, text = show.game_over_screen.score_record_line(plan.size(:score_record))
        color = game_over.new_score_record? ? pen.palette.gain : pen.palette.soft
        alpha = 0.85 + (0.15 * Math.sin(now * 6)) if game_over.new_score_record?
        pen.text(text, pen.fonts.public_send(face, size), rect.center_x, rect.center_y, color, alpha)
      end
    end
  end
end
