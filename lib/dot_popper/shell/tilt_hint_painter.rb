# frozen_string_literal: true

module DotPopper
  module Shell
    # Game Over's light line saying the pile can be played with: small,
    # quiet, under "Tap to continue", and coming in with it.
    class TiltHintPainter < Data.define(:pen)
      def draw(hint, show, layout)
        finale = show.finale or return
        alpha = finale.prompt(show.now) * look.hint_alpha
        return if alpha <= 0.0

        font = pen.fonts.semibold(layout.scaled(pen.look::TYPE.summary))
        y = layout.center_y + (layout.safe.height * look.hint_at)
        pen.text(hint, font, layout.center_x, y, pen.palette.soft, alpha)
      end

      private

      def look = pen.look::TILT
    end
  end
end
