# frozen_string_literal: true

module DotPopper
  module Shell
    # Game over, over the finished game, each line where the Show's
    # FinalePlan puts it: "Time's up!", "You met today's goal!" if the
    # game did, the score counting up, a new record or how far short of the
    # best it fell, a quiet line of the game's facts, a lifetime record
    # it set, "Share my score", rising in as the score lands, and the
    # Continue button, faint until a press will be heard. Every line
    # above Continue sits on a soft, dark backing, so they read over the
    # pile without hiding it. The stacking rule is taught on the pile
    # itself, with no word (Show#replay_slip).
    class FinalePainter < Data.define(:pen)
      def draw(show, layout)
        finale = show.finale or return
        plan = show.finale_plan
        now = show.now
        palette = pen.palette
        words = show.words
        arrival = finale.arrival(now)
        shown = arrival.clamp(0.0, 1.0)
        ScrimPainter.new(pen:).draw(plan.backing, pen.style::FINALE_BACKING, layout, alpha: shown)
        if (heading = plan[:heading])
          pen.text(words.time_up, pen.fonts.bold(plan.size(:heading)), layout.center_x,
                   heading.center_y - ((1 - arrival) * 30), palette.soft, shown)
        end
        goal_met(finale, words, plan, now)
        score = pen.fonts.bold(plan.size(:score))
        Lettering.new(pen:).candy(finale.shown_score(now).to_s, score, layout.center_x,
                                  plan[:score].y + (score.height / 2.0), shown)
        score_record_line(show, plan, now, shown)
        line(plan, :group, show.group_panel.game_line.to_s, palette.gain, shown) if plan[:group]
        line(plan, :summary, words.summary(finale.stats), palette.soft, shown * 0.8)
        line(plan, :record, words.record(finale.record), palette.gain, finale.afterword(now)) if finale.record && finale.counted?(now)
        line(plan, :achievement, Presentation::AchievementWords.earned(finale.achievements), palette.gain, finale.afterword(now)) if finale.achievements.any? && finale.counted?(now)
        if (button = plan.share_button)
          ShareButton.new(pen:).draw(button, words.share, cue: finale.share_cue(now), ui: layout.ui,
                                     hover: show.hover.level(:share))
        end
        PrimaryButton.new(pen:).draw(plan.continue_button, words.continue, alpha: [shown * 0.35, finale.prompt(now)].max,
                                     hover: show.hover.level(:continue))
      end

      private

      # A semibold line of +text+ in its place in +plan+, if it has one.
      def line(plan, name, text, color, alpha)
        rect = plan[name] or return

        pen.text(text, pen.fonts.semibold(plan.size(:summary)), rect.center_x, rect.center_y, color, alpha)
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

      # A new record, glowing, once the score has counted up, or how far
      # short of the best the game fell.
      def score_record_line(show, plan, now, alpha)
        rect = plan[:score_record] or return
        finale = show.finale
        return if finale.new_score_record? && !finale.counted?(now)

        face, size, text = show.finale_screen.score_record_line(plan.size(:score_record))
        color = finale.new_score_record? ? pen.palette.gain : pen.palette.soft
        alpha = 0.85 + (0.15 * Math.sin(now * 6)) if finale.new_score_record?
        pen.text(text, pen.fonts.public_send(face, size), rect.center_x, rect.center_y, color, alpha)
      end
    end
  end
end
