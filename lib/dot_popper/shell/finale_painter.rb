# frozen_string_literal: true

module DotPopper
  module Shell
    # Game over, over the finished round: "Time!", the score counting up,
    # the best score or a new best, and, once a tap will be heard, the
    # prompt to go on.
    class FinalePainter
      def initialize(pen)
        @pen = pen
      end

      def draw(show, layout)
        finale = show.finale or return
        now = show.now
        type = @pen.look::TYPE
        palette = @pen.palette
        words = show.words
        height = layout.safe.height
        center = layout.center_y
        arrival = finale.arrival(now)
        shown = arrival.clamp(0.0, 1.0)
        heading = @pen.fonts.bold(layout.scaled(type.heading))
        @pen.text(words.time_up, heading, layout.center_x, center - (height * 0.27) - ((1 - arrival) * 30),
                  palette.soft, shown)
        score = @pen.fonts.bold(layout.scaled(type.final_score))
        Lettering.new(@pen).candy(finale.shown_score(now).to_s, score, layout.center_x, center - (height * 0.06), shown)
        best_line(finale, words, layout, center + (height * 0.13), now, shown)
        prompt = @pen.fonts.bold(layout.scaled(type.prompt))
        @pen.text(words.continue, prompt, layout.center_x, center + (height * 0.28), palette.cream, finale.prompt(now))
      end

      private

      def best_line(finale, words, layout, y, now, alpha)
        type = @pen.look::TYPE
        if finale.new_best?
          return unless finale.counted?(now)

          font = @pen.fonts.bold(layout.scaled(type.new_best))
          glow = 0.85 + (0.15 * Math.sin(now * 6))
          @pen.text(words.new_best, font, layout.center_x, y, @pen.palette.gain, glow)
        else
          font = @pen.fonts.semibold(layout.scaled(type.best))
          @pen.text(words.best_line(finale.best), font, layout.center_x, y, @pen.palette.soft, alpha)
        end
      end
    end
  end
end
