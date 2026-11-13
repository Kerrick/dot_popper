# frozen_string_literal: true

module DotPopper
  # The game as a whole: Home, then Playing, then Game Over, then Home
  # again; or from Home, a game Paused before its clock first runs while
  # the tutorial plays over it, and then Playing. Each state is a value that answers +press+ and +update+ with
  # the state that follows it, so each transition reads in one place.
  # The Cabinet is the shell around them: it holds the current state, makes
  # games, keeps the score records, and tells its listeners every event, in
  # order. A game's records count among those of its SizeClass, the
  # class of the field it started on.
  #
  # +screen+ is the window as a Field at the usual dot size (DotSize);
  # +sizing+ (DotSizing) decides the radius a game's dots get on it.
  class Cabinet
    LARGEST_SEED = 2_147_483_648 # 2**31

    attr_reader :state, :score_record, :screen, :sizing

    def initialize(screen, score_record: ScoreRecord.new(ScoreRecord::Memory.new), random: Random.new,
                   sizing: DotSizing::STANDARD)
      @screen = screen
      @sizing = sizing
      @score_record = score_record
      @random = random
      @listeners = []
      @state = show_home
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener = nil, &block)
      @listeners << (listener || block || raise(ArgumentError, "subscribe needs a listener or a block"))
      self
    end

    def press(x, y) = advance(state.press(self, x, y))
    def update(seconds) = advance(state.update(self, seconds))

    # The game in play or just finished, or nil on Home.
    def game = state.game

    # The field a game started now would play on, and the class of
    # screen it would count among.
    def field = sizing.fit(screen)
    def size_class = sizing.size_class(screen)

    # The window changed size. A game in play keeps its dots on screen,
    # and their radius, and the next game starts on the new screen.
    def screen=(screen)
      @screen = screen
      state = self.state
      return unless state.is_a?(Playing) || state.is_a?(Paused)

      state.game.field = Field.new(screen.width, screen.height, state.game.field.radius)
    end

    # Whether the game is paused before its clock first runs (Paused).
    def paused? = state.is_a?(Paused)

    # The player chose how dots are sized. Only Home may change it,
    # so a game in play keeps the radius it started with.
    def sizing=(sizing)
      @sizing = sizing if state.is_a?(Home)
    end

    # Tells every listener of +event+; nil is nothing to tell.
    def announce(event)
      @listeners.each { |listener| listener.call(event) } if event
      event
    end

    # The transitions, each with the event that says it happened.

    def show_home
      announce(Events::HomeShown.new(score_record: score_record.of(size_class)))
      Home.new
    end

    # A game drawn from +seed+, by default one of its own from the
    # game's randomness. The game gets a Random of its own from its seed,
    # and draws from it only when a dot spawns, so the same seed and the
    # same taps give the same dots, whatever else uses randomness
    # meanwhile.
    def start_game(seed = @random.rand(LARGEST_SEED))
      begin_game(Game.new(field, random: Random.new(seed)), seed)
    end

    # From Home, a game made as #start_game makes one, with +dots+ (a
    # Stack) as its first, paused before its clock first runs, for the
    # tutorial to play over (Paused). Nothing is announced: its events
    # are the tutorial's until play begins (#unpause).
    def start_paused(dots, seed = @random.rand(LARGEST_SEED))
      return self unless state.is_a?(Home)

      advance(Paused.new(game: Game.new(field, random: Random.new(seed), dots:), seed:, size_class:))
    end

    # A press on the paused game, which only the tutorial makes: the rules
    # hear it as in play, and the event comes back to the tutorial alone.
    # Nil when no game is paused.
    def press_paused(x, y)
      state = self.state
      state.game.tap_at(x, y) if state.is_a?(Paused)
    end

    # Moves the paused game's dots +seconds+ on, at the tutorial's pace;
    # its clock stays as it is.
    def move_paused(seconds)
      state = self.state
      state.game.move_dots(seconds) if state.is_a?(Paused)
    end

    # Puts +dots+ in the paused game in place of the dots of their ids
    # (Game#arrange), as the tutorial shows them.
    def arrange(*dots)
      state = self.state
      state.game.arrange(*dots) if state.is_a?(Paused)
    end

    # Play begins on the paused game, as it is: it is announced as begun,
    # and its clock runs from the next update. It counts among the
    # records of the class of screen it was made on.
    def unpause
      state = self.state
      return self unless state.is_a?(Paused)

      advance(begin_game(state.game, state.seed, state.size_class))
    end

    # The game's score counts among the records of +size_class+, the class
    # it started in, even if the window changed size meanwhile.
    def finish(game, seed, size_class)
      first = score_record.first?(size_class)
      new_score_record = score_record.record(game.score, size_class)
      announce(Events::GameEnded.new(score_record: score_record.of(size_class), new_score_record:, seed:, size_class:, first:,
                                     field: game.field, dots: game.dots, score: game.score, elapsed: game.elapsed))
      GameOver.new(game:, new_score_record:)
    end

    private

    def begin_game(game, seed, size_class = self.size_class)
      announce(Events::GameStarted.new(seed:, field: game.field, dots: game.dots, score: game.score, dots_in_a_row: game.dots_in_a_row))
      Playing.new(game:, seed:, size_class:)
    end

    def advance(next_state)
      @state = next_state
      self
    end

    # Waiting to start. Any press begins a game.
    class Home < Data.define
      def game = nil
      def press(cabinet, _x, _y) = cabinet.start_game
      def update(_game, _seconds) = self
    end

    # A game in progress. It ends the moment the clock reaches zero,
    # whether time ran out or a penalty took the last of it.
    class Playing < Data.define(:game, :seed, :size_class)
      def press(cabinet, x, y)
        cabinet.announce(game.tap_at(x, y))
        settle(cabinet)
      end

      def update(cabinet, seconds)
        game.update(seconds)
        settle(cabinet)
      end

      private

      def settle(cabinet) = game.over? ? cabinet.finish(game, seed, size_class) : self
    end

    # A game made but not yet begun: its clock has not run, and while the
    # tutorial plays over it, no press reaches it but the ones the
    # tutorial passes on (Cabinet#press_paused), and its dots move only
    # as the tutorial moves them (Cabinet#move_paused).
    class Paused < Data.define(:game, :seed, :size_class)
      def press(_cabinet, _x, _y) = self
      def update(_cabinet, _seconds) = self
    end

    # The game is over and its score is shown. Presses are ignored for a
    # moment so a last frantic tap does not skip it; after that, a press
    # goes back to Home.
    class GameOver < Data.define(:game, :new_score_record, :shown)
      def initialize(game:, new_score_record:, shown: 0.0) = super

      def score = game.score
      def ready? = shown >= Rules::GAME_OVER_GRACE

      def press(cabinet, _x, _y) = ready? ? cabinet.show_home : self
      def update(_game, seconds) = with(shown: shown + seconds)
    end
  end
end
