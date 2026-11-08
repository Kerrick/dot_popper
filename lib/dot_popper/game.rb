# frozen_string_literal: true

module DotPopper
  # The game as a whole: Title, then Playing, then Game Over, then Title
  # again. Each state is a value that answers +press+ and +update+ with
  # the state that follows it, so each transition reads in one place.
  # The Game is the shell around them: it holds the current state, makes
  # rounds, keeps the best scores, and tells its listeners every event, in
  # order. A round's records count among those of its SizeClass, the
  # class of the field it started on.
  #
  # +screen+ is the window as a Field at the usual dot size (DotSize);
  # +sizing+ (DotSizing) decides the radius a round's dots get on it.
  class Game
    LARGEST_SEED = 2_147_483_648 # 2**31

    attr_reader :state, :best, :screen, :sizing

    def initialize(screen, best: BestScore.new(BestScore::Memory.new), random: Random.new,
                   sizing: DotSizing::STANDARD)
      @screen = screen
      @sizing = sizing
      @best = best
      @random = random
      @listeners = []
      @state = show_title
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener = nil, &block)
      @listeners << (listener || block || raise(ArgumentError, "subscribe needs a listener or a block"))
      self
    end

    def press(x, y) = advance(state.press(self, x, y))
    def update(seconds) = advance(state.update(self, seconds))

    # The round in play or just finished, or nil on the title.
    def round = state.round

    # The field a round started now would play on, and the class of
    # screen it would count among.
    def field = sizing.fit(screen)
    def size_class = sizing.size_class(screen)

    # The window changed size. A round in play keeps its dots on screen,
    # and their radius, and the next round starts on the new screen.
    def screen=(screen)
      @screen = screen
      state.round.field = Field.new(screen.width, screen.height, state.round.field.radius) if state.is_a?(Playing)
    end

    # The player chose how dots are sized. Only the title may change it,
    # so a round in play keeps the radius it started with.
    def sizing=(sizing)
      @sizing = sizing if state.is_a?(Title)
    end

    # Tells every listener of +event+; nil is nothing to tell.
    def announce(event)
      @listeners.each { |listener| listener.call(event) } if event
      event
    end

    # The transitions, each with the event that says it happened.

    def show_title
      announce(Events::TitleShown.new(best: best.of(size_class)))
      Title.new
    end

    # A round drawn from +seed+, by default one of its own from the
    # game's randomness. The round gets a Random of its own from its seed,
    # and draws from it only when a dot spawns, so the same seed and the
    # same taps give the same dots, whatever else uses randomness
    # meanwhile.
    def start_round(seed = @random.rand(LARGEST_SEED))
      begin_round(Round.new(field, random: Random.new(seed)), seed)
    end

    # From the title, the round that goes on from where the tutorial left
    # its +dots+, +score+ and +seconds+, on its +field+ (Round.resume). The
    # clock was never running before, so nothing was scored or timed
    # outside Playing; from here the round counts as any other does. Its
    # new dots are drawn from a seed of its own, as #start_round's are.
    def resume(field:, dots:, score:, seconds:)
      return self unless state.is_a?(Title)

      seed = @random.rand(LARGEST_SEED)
      advance(begin_round(Round.resume(field, dots:, score:, seconds:, random: Random.new(seed)), seed))
    end

    # The round's score counts among the bests of +size_class+, the class
    # it started in, even if the window changed size meanwhile.
    def finish(round, seed, size_class)
      first = best.first?(size_class)
      new_best = best.record(round.score, size_class)
      announce(Events::RoundEnded.new(round:, best: best.of(size_class), new_best:, seed:, size_class:, first:))
      GameOver.new(round:, new_best:)
    end

    private

    def begin_round(round, seed)
      announce(Events::RoundStarted.new(round:, seed:))
      Playing.new(round:, seed:, size_class:)
    end

    def advance(next_state)
      @state = next_state
      self
    end

    # Waiting to start. Any press begins a round.
    class Title < Data.define
      def round = nil
      def press(game, _x, _y) = game.start_round
      def update(_game, _seconds) = self
    end

    # A round in progress. It ends the moment the clock reaches zero,
    # whether time ran out or a penalty took the last of it.
    class Playing < Data.define(:round, :seed, :size_class)
      def press(game, x, y)
        game.announce(round.tap_at(x, y))
        settle(game)
      end

      def update(game, seconds)
        round.update(seconds)
        settle(game)
      end

      private

      def settle(game) = round.over? ? game.finish(round, seed, size_class) : self
    end

    # The round is over and its score is shown. Presses are ignored for a
    # moment so a last frantic tap does not skip it; after that, a press
    # goes back to the title.
    class GameOver < Data.define(:round, :new_best, :shown)
      def initialize(round:, new_best:, shown: 0.0) = super

      def score = round.score
      def ready? = shown >= Rules::GAME_OVER_GRACE

      def press(game, _x, _y) = ready? ? game.show_title : self
      def update(_game, seconds) = with(shown: shown + seconds)
    end
  end
end
