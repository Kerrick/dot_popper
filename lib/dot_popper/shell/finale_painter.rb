# frozen_string_literal: true

module DotPopper
  module Shell
    # Game over, over the finished round, each line where the Show's
    # FinalePlan puts it: "Time's up!", "You met today's goal!" if the
    # round did, the score counting up, a new best or how far short of the
    # best it fell, a quiet line of the round's facts, a lifetime record
    # it set, "Copy my result", and, once a tap will be heard, the prompt
    # to go on. On the first Game Overs after a wrong tap with the bright
    # dot hidden, the stacking rule comes first. Every line sits on a
    # soft, dark backing, so they read over the pile without hiding it.
    class FinalePainter < Data.define(:pen)
      def draw(show, layout)
        finale = show.finale or return
        plan = show.finale_plan
        now = show.now
        palette = pen.palette
        words = show.words
        arrival = finale.arrival(now)
        shown = arrival.clamp(0.0, 1.0)
        ScrimPainter.new(pen:).draw(plan.backing, pen.look::FINALE_BACKING, layout, alpha: shown)
        lesson(plan, layout, shown) if plan[:lesson]
        if (heading = plan[:heading])
          pen.text(words.time_up, pen.fonts.bold(plan.size(:heading)), layout.center_x,
                   heading.center_y - ((1 - arrival) * 30), palette.soft, shown)
        end
        goal_met(finale, words, plan, now)
        score = pen.fonts.bold(plan.size(:score))
        Lettering.new(pen:).candy(finale.shown_score(now).to_s, score, layout.center_x,
                                  plan[:score].y + (score.height / 2.0), shown)
        best_line(show, plan, now, shown)
        line(plan, :summary, words.summary(finale.stats), palette.soft, shown * 0.8)
        line(plan, :record, words.record(finale.record), palette.gain, finale.afterword(now)) if finale.record && finale.counted?(now)
        if (button = plan.share_button)
          copied = finale.copied?(now)
          PillButton.new(pen:).draw(button, copied ? words.copied : words.share, alpha: shown,
                                    color: copied ? palette.gain : palette.cream)
        end
        pen.text(words.continue, pen.fonts.bold(plan.size(:continue)), layout.center_x, plan[:continue].center_y,
                 palette.cream, finale.prompt(now))
      end

      private

      # A semibold line of +text+ in its place in +plan+, if it has one.
      def line(plan, name, text, color, alpha)
        rect = plan[name] or return

        pen.text(text, pen.fonts.semibold(plan.size(:summary)), rect.center_x, rect.center_y, color, alpha)
      end

      # The stacking rule, in the lines the plan broke it into, in the
      # hint's size and bold, since it is the one thing on this screen the
      # player has not seen before.
      def lesson(plan, layout, alpha)
        font = pen.fonts.bold(plan.size(:lesson))
        step = font.height * 1.05
        top = plan[:lesson].y + (font.height / 2.0)
        plan.lesson_lines.each_with_index do |line, i|
          pen.text(line, font, layout.center_x, top + (step * i), pen.palette.cream, alpha * pen.look::LESSON.alpha)
        end
      end

      # "You met today's goal!", with a check, between "Time's up!" and the
      # score, once the score has counted up; the Show bursts twinkles
      # there as it appears.
      def goal_met(finale, words, plan, now)
        rect = plan[:goal]
        return unless rect && finale.counted?(now)

        font = pen.fonts.bold(plan.size(:goal))
        Check.new(pen:).labelled(words.goal_met, font, rect.center_x, rect.center_y, finale.afterword(now))
      end

      # A new best, glowing, once the score has counted up, or how far
      # short of the best the round fell.
      def best_line(show, plan, now, alpha)
        rect = plan[:best] or return
        finale = show.finale
        return if finale.new_best? && !finale.counted?(now)

        face, size, text = show.finale_screen.best_line(plan.size(:best))
        color = finale.new_best? ? pen.palette.gain : pen.palette.soft
        alpha = 0.85 + (0.15 * Math.sin(now * 6)) if finale.new_best?
        pen.text(text, pen.fonts.public_send(face, size), rect.center_x, rect.center_y, color, alpha)
      end
    end
  end
end
