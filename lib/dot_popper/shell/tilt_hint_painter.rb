# frozen_string_literal: true

module DotPopper
  module Shell
    # Game Over's light line saying the pile can be played with: small,
    # quiet, under "Tap to continue" where the FinalePlan puts it, and
    # coming in with it.
    class TiltHintPainter < Data.define(:pen)
      def draw(hint, show)
        finale = show.finale or return
        alpha = finale.prompt(show.now) * look.hint_alpha
        return if alpha <= 0.0

        plan = show.finale_plan
        rect = plan[:hint] or return

        pen.text(hint, pen.fonts.semibold(plan.size(:summary)), rect.center_x, rect.center_y, pen.palette.soft, alpha)
      end

      private

      def look = pen.look::TILT
    end
  end
end
