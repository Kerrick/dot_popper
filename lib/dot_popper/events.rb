# frozen_string_literal: true

module DotPopper
  # What the rules report as they happen, for whatever wants to show them.
  # Each is a frozen value, decided before anyone hears of it: by the time
  # a listener runs, the score, the clock, and the dots have already
  # changed.
  module Events
    # A fresh dot was tapped and popped; +spawned+ is the dot that took
    # its place underneath.
    class Popped < Data.define(:dot, :x, :y, :points, :seconds, :spawned); end

    # A popped dot was tapped. +points+ is what the score actually lost,
    # which is less than the penalty when the score was near zero.
    class Penalized < Data.define(:dot, :x, :y, :points, :seconds)
      # Whether the score floor kept part of the penalty from landing.
      def softened? = points > -Rules::PENALTY_POINTS
    end

    # A tap hit no dot.
    class Missed < Data.define(:x, :y); end

    # A round began, in +mode+.
    class RoundStarted < Data.define(:round, :mode); end

    # A round's clock reached zero; +best+ is the device's best score
    # after this round, +new_best+ whether this round set it, and +mode+
    # how the round was started. A daily round also has that day's
    # +daily_best+ after it, and +new_daily_best+ whether it set it.
    class RoundEnded < Data.define(:round, :best, :new_best, :mode, :daily_best, :new_daily_best)
      def initialize(round:, best:, new_best:, mode:, daily_best: nil, new_daily_best: false) = super

      def score = round.score
    end

    # The title screen came up.
    class TitleShown < Data.define(:best); end
  end
end
