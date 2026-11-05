# frozen_string_literal: true

module DotPopper
  module Presentation
    # Game over, shown since +at+: the round dimming behind, the heading
    # arriving, the score counting up, and the prompt to go on, which
    # shows only from +ready_at+, once a press would be heard. A new best
    # is celebrated once, when it has finished counting. +stats+ are the
    # round's RoundStats, for the line of facts under the score.
    # +copied_at+ is when the result was last copied to share. +record+
    # is the most impressive lifetime record the round set
    # (LifetimeStats::Record), or nil.
    class Finale < Data.define(:look, :score, :best, :new_best, :at, :stats, :record, :copied_at, :ready_at,
                               :celebrated)
      COPIED_FOR = 1.6 # seconds "Copy my result" says "Copied!"

      def initialize(look:, score:, best:, new_best:, at:, stats: RoundStats.start, record: nil, copied_at: nil,
                     ready_at: nil, celebrated: false)
        super
      end

      def copy(now) = with(copied_at: now)
      def copied?(now) = !copied_at.nil? && now - copied_at < COPIED_FOR

      def new_best? = new_best

      def dim(now) = look.dim.at(now - at)
      def arrival(now) = look.arrive.at(now - at)

      def shown_score(now) = (score * look.tally.progress(now - at)).round
      def counted?(now) = look.tally.done?(now - at)

      # The finale once the game says it will take a press.
      def ready(now) = ready_at ? self : with(ready_at: now)
      def prompt(now) = ready_at ? look.prompt.at(now - ready_at) : 0.0

      def celebration_due?(now) = new_best? && !celebrated && counted?(now)
      def celebrate = with(celebrated: true)
    end
  end
end
