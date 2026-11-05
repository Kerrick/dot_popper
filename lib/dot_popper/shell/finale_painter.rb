# frozen_string_literal: true

module DotPopper
  module Shell
    # Game over, over the finished round: "Time!", the score counting up,
    # a new best or how far short of the best it fell, a quiet line of the
    # round's facts, a lifetime record it set, "You met today's goal!" if
    # it did, "Copy my result", and, once a tap will be heard, the prompt
    # to go on. On the first Game Overs after a wrong tap with the bright
    # dot hidden, the stacking rule sits between the HUD, whose bottom is
    # at +below+, and "Time's up!", away from the score. From "Time's up!"
    # to "Tap to continue", the words sit on a soft, dark backing, so they
    # read over the pile without hiding it.
    class FinalePainter < Data.define(:pen)
      def draw(show, layout, below: layout.top)
        finale = show.finale or return
        now = show.now
        type = pen.look::TYPE
        palette = pen.palette
        words = show.words
        height = layout.safe.height
        center = layout.center_y
        arrival = finale.arrival(now)
        shown = arrival.clamp(0.0, 1.0)
        heading = pen.fonts.bold(layout.scaled(type.heading))
        heading_y = center - (height * (0.27 - (finale.lesson ? pen.look::LESSON.room : 0.0)))
        summary = pen.fonts.semibold(layout.scaled(type.summary))
        backing(show, layout, heading_y - (heading.height * 0.4), [heading.width(words.time_up),
                                                                   summary.width(words.summary(finale.stats))], shown)
        pen.text(words.time_up, heading, layout.center_x, heading_y - ((1 - arrival) * 30), palette.soft, shown)
        lesson(finale.lesson, layout, below, heading_y - (layout.scaled(type.heading) * 0.36), shown) if finale.lesson
        score = pen.fonts.bold(layout.scaled(type.final_score))
        Lettering.new(pen:).candy(finale.shown_score(now).to_s, score, layout.center_x, center - (height * 0.06), shown)
        best_line(finale, words, layout, center + (height * 0.13), now, shown)
        pen.text(words.summary(finale.stats), summary, layout.center_x, center + (height * 0.19), palette.soft,
                 shown * 0.8)
        record(finale, words, layout, center + (height * 0.235), now)
        goal_met(finale, words, layout, now)
        copied = finale.copied?(now)
        PillButton.new(pen:).draw(layout.share_button, copied ? words.copied : words.share, alpha: shown,
                                  color: copied ? palette.gain : palette.cream)
        prompt = pen.fonts.bold(layout.scaled(type.prompt))
        pen.text(words.continue, prompt, layout.center_x, layout.continue_y, palette.cream,
                 finale.prompt(now))
      end

      private

      # The backing from +top+ down to the prompt's bottom, as wide as the
      # widest of the block's lines, +widths+, the share button, and a
      # record if the round set one, and never past the safe area.
      def backing(show, layout, top, widths, alpha)
        finale = show.finale
        prompt = pen.fonts.bold(layout.scaled(pen.look::TYPE.prompt))
        widths << prompt.width(show.words.continue) << layout.share_button.width
        if finale.record
          widths << pen.fonts.semibold(layout.scaled(pen.look::TYPE.summary)).width(show.words.record(finale.record))
        end
        look = pen.look::FINALE_BACKING
        width = [widths.max, layout.safe.width - (2 * (look.pad + look.feather) * layout.ui)].min
        bottom = layout.continue_y + (prompt.height * 0.5)
        rect = Presentation::Rect.new(x: layout.center_x - (width / 2.0), y: top, width:, height: bottom - top)
        ScrimPainter.new(pen:).draw(rect, look, layout, alpha:)
      end

      # The stacking rule, a sentence a line (each broken evenly if it
      # would not fit across), centred between +top+ and +bottom+.
      def lesson(sentences, layout, top, bottom, alpha)
        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.summary))
        room = layout.safe.width - (layout.margin * 3)
        lines = sentences.flat_map { |sentence| Presentation::Words.balance(sentence, room) { font.width(it) } }
        step = font.height * 0.98
        top = ((top + bottom) / 2.0) - (step * lines.size / 2.0)
        lines.each_with_index do |line, i|
          pen.text(line, font, layout.center_x, top + (step * (i + 0.5)), pen.palette.cream,
                   alpha * pen.look::LESSON.alpha)
        end
      end

      # The lifetime record the round set, if any, once the score has
      # counted up: quiet, in the colour of a gain.
      def record(finale, words, layout, y, now)
        return unless finale.record && finale.counted?(now)

        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.summary))
        pen.text(words.record(finale.record), font, layout.center_x, y, pen.palette.gain, finale.afterword(now))
      end

      # "You met today's goal!", with a check, between "Time's up!" and the
      # score, once the score has counted up; the Show bursts twinkles
      # there as it appears.
      def goal_met(finale, words, layout, now)
        return unless finale.goal_met && finale.counted?(now)

        font = pen.fonts.bold(layout.scaled(pen.look::TYPE.best))
        Check.new(pen:).labelled(words.goal_met, font, layout.center_x, layout.finale_goal_y, finale.afterword(now))
      end

      def best_line(finale, words, layout, y, now, alpha)
        type = pen.look::TYPE
        if finale.new_best?
          return unless finale.counted?(now)

          font = pen.fonts.bold(layout.scaled(type.new_best))
          glow = 0.85 + (0.15 * Math.sin(now * 6))
          pen.text(words.new_best, font, layout.center_x, y, pen.palette.gain, glow)
        else
          font = pen.fonts.semibold(layout.scaled(type.best))
          pen.text(words.short_of_best(finale.score, finale.best), font, layout.center_x, y, pen.palette.soft, alpha)
        end
      end
    end
  end
end
