# frozen_string_literal: true

module DotPopper
  # What the rules report as they happen, for whatever wants to show them.
  # Each is a frozen value, decided before anyone hears of it: by the time
  # a listener runs, the score, the clock, and the dots have already
  # changed.
  module Events
    # A bright dot was tapped and popped; +spawned+ is the dot that took
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

    # Play began on a game, its dots drawn from +seed+: at once from Play,
    # or, for a game the tutorial plays over, as the tutorial ends or is
    # skipped (Cabinet#unpause).
    class GameStarted < Data.define(:game, :seed); end

    # A game's clock reached zero; +score_record+ is the device's score record on
    # screens of +size_class+ (SizeClass) after this game, +new_score_record+
    # whether this game set it, +first+ whether it was the first game on
    # such screens, which sets a record but is never a new one, and +seed+
    # the one its dots were drawn from.
    class GameEnded < Data.define(:game, :score_record, :new_score_record, :seed, :size_class, :first)
      def initialize(game:, score_record:, new_score_record:, seed:, size_class:, first: false) = super

      def score = game.score
    end

    # Home came up; +score_record+ is the score record on screens like
    # this one.
    class HomeShown < Data.define(:score_record); end
  end
end
