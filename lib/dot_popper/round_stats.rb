# frozen_string_literal: true

module DotPopper
  # What happened in one round, in numbers a player can learn from: how
  # many dots were popped, how many wrong taps (slips) there were and how
  # many of those the score floor softened, how long each fresh dot took
  # to pop from when it appeared (its wait), and how long the round ran.
  # It is built from the rules' events, so it decides nothing.
  class RoundStats < Data.define(:pops, :slips, :softened, :waits, :fresh_since, :duration)
    def self.start = new(pops: 0, slips: 0, softened: 0, waits: [], fresh_since: 0.0, duration: 0.0)

    def initialize(pops:, slips:, softened:, waits:, fresh_since:, duration:)
      super(pops:, slips:, softened:, waits: waits.dup.freeze, fresh_since: fresh_since.to_f, duration: duration.to_f)
    end

    # The stats after +event+, which happened +at+ seconds into the round.
    def record(event, at:)
      case event
      when Events::Popped then with(pops: pops + 1, waits: waits + [at - fresh_since], fresh_since: at)
      when Events::Penalized then with(slips: slips + 1, softened: softened + (event.softened? ? 1 : 0))
      when Events::RoundEnded then with(duration: at)
      else self
      end
    end

    # The longest any popped dot kept the player waiting, in seconds.
    def longest_wait = waits.max || 0.0

    # The mean time from a fresh dot appearing to its pop, in seconds.
    def mean_wait = waits.empty? ? 0.0 : waits.sum / waits.size

    # Listens to a Game (Game#subscribe) and keeps the stats of the round
    # in play, or of the one just finished.
    class Recorder
      attr_reader :stats

      def initialize
        @stats = RoundStats.start
        @round = nil
      end

      def call(event)
        case event
        when Events::RoundStarted
          @round = event.round
          @stats = RoundStats.start
        when Events::Popped, Events::Penalized, Events::RoundEnded
          @stats = stats.record(event, at: @round&.elapsed || 0.0)
        end
      end
    end
  end
end
