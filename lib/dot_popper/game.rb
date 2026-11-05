# frozen_string_literal: true

module DotPopper
  # The game as a whole: Title, then Playing, then Game Over, then Title
  # again. Each state is an object that answers +press+ and +update+ and
  # returns the state that follows it, so the transitions read in one
  # place each. Listeners hear every event the rules report, in order.
  class Game
    attr_reader :state, :best, :field

    def initialize(field, best: BestScore.new(BestScore::Memory.new), random: Random.new)
      @field = field
      @best = best
      @random = random
      @listeners = []
      @state = Title.new(self)
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener = nil, &block)
      @listeners << (listener || block)
      self
    end

    def press(x, y) = transition(state.press(x, y))
    def update(seconds) = transition(state.update(seconds))

    # The window changed size. A round in play keeps its dots on screen;
    # the next round starts on the new field.
    def field=(field)
      @field = field
      state.round.field = field if state.respond_to?(:round)
    end

    def round = state.respond_to?(:round) ? state.round : nil

    def announce(event)
      @listeners.each { |listener| listener.call(event) }
      event
    end

    def new_round = Round.new(field, random: @random)

    private

    def transition(next_state)
      @state = next_state
      self
    end

    # Waiting to start. Any press begins a round.
    class Title
      def initialize(game)
        @game = game
        game.announce(Events::TitleShown.new(best: game.best.value))
      end

      def press(_x, _y) = Playing.new(@game)
      def update(_seconds) = self
    end

    # A round in progress. It ends the moment the clock reaches zero,
    # whether time ran out or a penalty took the last of it.
    class Playing
      attr_reader :round

      def initialize(game)
        @game = game
        @round = game.new_round
        game.announce(Events::RoundStarted.new(round:))
      end

      def press(x, y)
        event = round.tap_at(x, y)
        @game.announce(event) if event
        settle
      end

      def update(seconds)
        round.update(seconds)
        settle
      end

      private

      def settle = round.over? ? GameOver.new(@game, round) : self
    end

    # The round is over and its score is shown. Presses are ignored for a
    # moment so a last frantic tap does not skip it; after that, a press
    # goes back to the title.
    class GameOver
      attr_reader :round, :new_best

      def initialize(game, round)
        @game = game
        @round = round
        @shown = 0.0
        @new_best = game.best.record(round.score)
        game.announce(Events::RoundEnded.new(round:, best: game.best.value, new_best:))
      end

      def score = round.score
      def ready? = @shown >= Rules::GAME_OVER_GRACE

      def press(_x, _y) = ready? ? Title.new(@game) : self

      def update(seconds)
        @shown += seconds
        self
      end
    end
  end
end
