# frozen_string_literal: true

module DotPopper
  # What happened in one game, in numbers a player can learn from: how
  # many dots were popped, how many wrong taps (slips) there were and how
  # many of those the score floor softened, how long each fresh dot took
  # to pop from when it appeared (its wait), how long the game ran, the
  # score, and the pops in a row since the last wrong tap (+run+) with the
  # most of those the game had (+longest_run+), and how many of the pops
  # were of bonus dots (+bonuses+). It is built from the
  # rules' events, so it decides nothing.
  class GameStats < Data.define(:pops, :slips, :softened, :waits, :fresh_since, :duration, :score, :run, :longest_run,
                                          :bonuses)
    def self.start = new(pops: 0, slips: 0, softened: 0, waits: [], fresh_since: 0.0, duration: 0.0)

    # The stats of +game+ as it starts: none for a game begun afresh;
    # for one that goes on from the tutorial (Game.resume), a pop for
    # each of its popped dots, in a row, and its score. Those pops came
    # before the clock ran, so none has a wait.
    def self.opening(game)
      pops = game.dots.count(&:popped?)
      start.with(pops:, score: game.score, run: pops, longest_run: pops)
    end

    def initialize(pops:, slips:, softened:, waits:, fresh_since:, duration:, score: 0, run: 0, longest_run: 0, bonuses: 0)
      super(pops:, slips:, softened:, waits: waits.dup.freeze, fresh_since: fresh_since.to_f, duration: duration.to_f,
            score:, run:, longest_run:, bonuses:)
    end

    # The stats after +event+, which happened +at+ seconds into the game.
    def record(event, at:)
      case event
      when Events::Popped then popped(event, at)
      when Events::Penalized
        with(slips: slips + 1, softened: softened + (event.softened? ? 1 : 0), score: score + event.points, run: 0)
      when Events::GameEnded then with(duration: at)
      else self
      end
    end

    # The longest any popped dot kept the player waiting, in seconds.
    def longest_wait = waits.max || 0.0

    # The shortest time a fresh dot was on screen before it was popped, in
    # seconds, or nil with nothing popped.
    def fastest_pop = waits.min

    # The mean time from a fresh dot appearing to its pop, in seconds.
    def mean_wait = waits.empty? ? 0.0 : waits.sum / waits.size

    # How many dots were popped in the game's first +seconds+.
    def pops_within(seconds)
      at = 0.0
      waits.count { (at += it) <= seconds }
    end

    # Listens to a Cabinet (Cabinet#subscribe) and keeps the stats of the game
    # in play, or of the one just finished.
    class Recorder
      attr_reader :stats

      def initialize
        @stats = GameStats.start
        @game = nil
      end

      def call(event)
        case event
        when Events::GameStarted
          @game = event.game
          @stats = GameStats.opening(event.game)
        when Events::Popped, Events::Penalized, Events::GameEnded
          @stats = stats.record(event, at: @game&.elapsed || 0.0)
        end
      end
    end

    private

    def popped(event, at)
      ran = run + 1
      with(pops: pops + 1, waits: waits + [at - fresh_since], fresh_since: at, score: score + event.points, run: ran,
           longest_run: [longest_run, ran].max, bonuses: bonuses + (event.dot.bonus? ? 1 : 0))
    end
  end
end
