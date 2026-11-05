# frozen_string_literal: true

module DotPopper
  module Presentation
    # Game over, shown since +at+: the round dimming behind, the heading
    # arriving, the score counting up, and the prompt to go on, which
    # shows only from +ready_at+, once a press would be heard. A new best
    # is celebrated once, when it has finished counting. +stats+ are the
    # round's RoundStats, for the line of facts under the score. After a
    # daily round (+mode+), it shows the day's best, and +copied_at+ is
    # when the result was last copied to share.
    class Finale < Data.define(:look, :score, :best, :new_best, :at, :stats, :mode, :daily_best, :new_daily_best,
                               :copied_at, :ready_at, :celebrated)
      COPIED_FOR = 1.6 # seconds the Share button says "Copied!"

      def initialize(look:, score:, best:, new_best:, at:, stats: RoundStats.start, mode: nil, daily_best: nil,
                     new_daily_best: false, copied_at: nil, ready_at: nil, celebrated: false)
        super
      end

      def daily? = mode&.daily? || false
      def date = mode&.date

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
