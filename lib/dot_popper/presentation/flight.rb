# frozen_string_literal: true

module DotPopper
  module Presentation
    # A number flying in the Tutorial, from +from+ to +to+ (Anchors), for
    # +duration+ seconds from +born+: a pop's "+1" into the HUD's score, or
    # a wrong tap's "−2" out of it. With +icon+ :stopwatch, a small drawn
    # stopwatch goes beside the number, for the time.
    class Flight < Data.define(:text, :icon, :color, :from, :to, :born, :duration)
      def initialize(text:, color:, from:, to:, born:, duration:, icon: nil) = super

      # Whether it is in the air at +now+: born, and not yet landed.
      def flying?(now) = now >= born && now - born < duration

      # How far along its way it is, eased: a flight into the HUD speeds up
      # and settles into the number, and one out of it leaps out and slows.
      def progress(now)
        t = ((now - born) / duration).clamp(0.0, 1.0)
        into_hud? ? Ease.in_out_sine(t) : Ease.out_cubic(t)
      end

      # Fully there as it flies; one into the HUD melts into its number at
      # the end, and one out of it fades as it goes.
      def alpha(now)
        t = ((now - born) / duration).clamp(0.0, 1.0)
        return 1 - ((t - 0.85) / 0.15).clamp(0.0, 1.0) if into_hud?

        1 - Ease.in_quad(((t - 0.35) / 0.65).clamp(0.0, 1.0))
      end

      def into_hud? = to.hud? && !from.hud?
    end
  end
end
