# frozen_string_literal: true

module DotPopper
  module Presentation
    # Game over as it shows at a moment: the round dimming behind, the
    # heading arriving, the score counting up, and the prompt to go on,
    # which shows only once a press would be heard.
    class Finale
      attr_reader :score, :best

      def initialize(look, score:, best:, new_best:, at:)
        @look = look
        @score = score
        @best = best
        @new_best = new_best
        @at = at
        @ready_at = nil
        @celebrated = false
      end

      def new_best? = @new_best

      def dim(now) = @look.dim.at(now - @at)
      def arrival(now) = @look.arrive.at(now - @at)

      def shown_score(now) = (score * @look.tally.progress(now - @at)).round
      def counted?(now) = @look.tally.done?(now - @at)

      # The game says when it will take a press again.
      def ready!(now) = @ready_at ||= now
      def prompt(now) = @ready_at ? @look.prompt.at(now - @ready_at) : 0.0

      # True once, when a new best has finished counting up.
      def celebrate?(now)
        return false if @celebrated || !new_best? || !counted?(now)

        @celebrated = true
      end
    end
  end
end
