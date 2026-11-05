# frozen_string_literal: true

module DotPopper
  module Presentation
    # How one number moves over time: from +from+ to +to+ in +duration+
    # seconds, along the easing curve +ease+ (an Ease name). A tween is a
    # spec, not a clock: ask it where the number is a given time after the
    # motion began.
    class Tween < Data.define(:from, :to, :duration, :ease)
      def initialize(from:, to:, duration:, ease: :out_cubic) = super

      def at(elapsed) = from + ((to - from) * progress(elapsed))

      def progress(elapsed)
        return 1.0 if duration <= 0

        Ease.by_name(ease, elapsed / duration)
      end

      def done?(elapsed) = elapsed >= duration
    end
  end
end
