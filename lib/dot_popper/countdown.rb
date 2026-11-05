# frozen_string_literal: true

module DotPopper
  # The round's clock. It counts down in real time, takes rewards and
  # penalties, and never shows less than zero.
  class Countdown
    attr_reader :remaining

    def initialize(seconds)
      @remaining = seconds.to_f
    end

    def tick(seconds) = adjust(-seconds)

    # Adds +seconds+, or takes them away when negative. Time stops at zero.
    def adjust(seconds)
      @remaining = [remaining + seconds, 0.0].max
      self
    end

    def expired? = remaining <= 0
    def whole_seconds = remaining.floor
  end
end
