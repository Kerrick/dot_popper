# frozen_string_literal: true

module DotPopper
  module Presentation
    # A number that eases from +from+ to +to+ over +duration+ seconds from
    # +at+, and rests there: how fast the Tutorial's time flows. Easing in
    # and out, it never snaps from one value to the next.
    class Level < Data.define(:from, :to, :at, :duration)
      # A level that stays at +value+.
      def self.steady(value) = new(from: value, to: value, at: 0.0, duration: 0.0)

      def value(now)
        return to if duration <= 0 || now >= at + duration

        from + ((to - from) * Ease.in_out_sine((now - at) / duration))
      end

      # The level easing from where it is at +now+ to +target+ over
      # +duration+ seconds.
      def toward(target, now, duration) = with(from: value(now), to: target, at: now, duration:)
    end
  end
end
