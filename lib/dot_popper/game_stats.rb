# frozen_string_literal: true

module DotPopper
  # What happened in one game, in numbers a player can learn from: how
  # many dots were popped, how many mistakes there were and how
  # many of those the score floor softened, how long each bright dot took
  # to pop from when it appeared (its wait), how long the game ran, the
  # score, and the dots in a row since the last mistake (+dots_in_a_row+) with the
  # most of those the game had (+most_dots_in_a_row+), and how many of the dots popped
  # were bonus dots (+bonuses+). It is built from the
  # rules' events, so it decides nothing.
  class GameStats < Data.define(:dots_popped, :mistakes, :softened, :times_to_pop, :bright_since, :duration, :score, :dots_in_a_row, :most_dots_in_a_row,
                                          :bonuses)
    def self.start = new(dots_popped: 0, mistakes: 0, softened: 0, times_to_pop: [], bright_since: 0.0, duration: 0.0)

    # The stats of +game+ as play begins: none for a game begun afresh;
    # for one the tutorial played over while it was paused
    # (Cabinet::Paused), each of its popped dots, its score, and
    # its row. Those dots were popped before the clock ran, so none has a wait;
    # and the guide's mistake, which the player did not make, is not one
    # of theirs.
    def self.opening(game)
      dots_popped = game.dots.count(&:popped?)
      start.with(dots_popped:, score: game.score, dots_in_a_row: game.dots_in_a_row, most_dots_in_a_row: game.dots_in_a_row)
    end

    def initialize(dots_popped:, mistakes:, softened:, times_to_pop:, bright_since:, duration:, score: 0, dots_in_a_row: 0, most_dots_in_a_row: 0, bonuses: 0)
      super(dots_popped:, mistakes:, softened:, times_to_pop: times_to_pop.dup.freeze, bright_since: bright_since.to_f, duration: duration.to_f,
            score:, dots_in_a_row:, most_dots_in_a_row:, bonuses:)
    end

    # The stats after +event+, which happened +at+ seconds into the game.
    def record(event, at:)
      case event
      when Events::Popped then popped(event, at)
      when Events::Penalized
        with(mistakes: mistakes + 1, softened: softened + (event.softened? ? 1 : 0), score: score + event.points, dots_in_a_row: 0)
      when Events::GameEnded then with(duration: at)
      else self
      end
    end

    # The longest any popped dot kept the player waiting, in seconds.
    def longest_time_to_pop = times_to_pop.max || 0.0

    # The shortest time a bright dot was on screen before it was popped, in
    # seconds, or nil with nothing popped.
    def shortest_time_to_pop = times_to_pop.min

    # The mean time from a bright dot appearing to its pop, in seconds.
    def mean_time_to_pop = times_to_pop.empty? ? 0.0 : times_to_pop.sum / times_to_pop.size

    # How many dots were popped in the game's first +seconds+.
    def dots_popped_within(seconds)
      at = 0.0
      times_to_pop.count { (at += it) <= seconds }
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
      ran = dots_in_a_row + 1
      with(dots_popped: dots_popped + 1, times_to_pop: times_to_pop + [at - bright_since], bright_since: at, score: score + event.points, dots_in_a_row: ran,
           most_dots_in_a_row: [most_dots_in_a_row, ran].max, bonuses: bonuses + (event.dot.bonus? ? 1 : 0))
    end
  end
end
