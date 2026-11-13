# frozen_string_literal: true

module DotPopper
  # The game as a whole: Home, then Playing, then Game Over, then Home
  # again; or from Home, a game Paused before its clock first runs while
  # the tutorial plays over it, and then Playing. A game is started only
  # by being asked to, never by a press, and only through the cabinet's
  # Starts, which it hands out once (#starts). Each state is a value that
  # answers +press+ and +update+ with the state that follows it, so each
  # transition reads in one place.
  # The Cabinet is the shell around them: it holds the current state, makes
  # games, keeps the score records, and tells its listeners every event, in
  # order. It alone holds the game (Game), and hands its states, and
  # anyone who asks (#game), only the game's read-only Game::View. A game's records count among those of its SizeClass, the
  # class of the field it started on.
  #
  # +screen+ is the window as a Field at the usual dot size (DotSize);
  # +sizing+ (DotSizing) decides the radius a game's dots get on it.
  class Cabinet
    LARGEST_SEED = 2_147_483_648 # 2**31

    attr_reader :state, :score_record, :screen, :sizing

    def initialize(screen, score_record: ScoreRecord.new(ScoreRecord::Memory.new), random: Random.new,
                   sizing: DotSizing::BIGGER_OR_SMALLER)
      @screen = screen
      @sizing = sizing
      @score_record = score_record
      @random = random
      @listeners = []
      @game = nil # the game in play, paused or just finished, which only the cabinet holds
      @starts_taken = false
      @state = show_home
    end

    # Asked for a cabinet's Starts a second time.
    class StartsTaken < StandardError; end

    # The one way to start a game on this cabinet (Starts), handed out
    # once, to the one thing that starts every game (UseCases::StartGame,
    # which the composition root makes): asked again, it raises, so
    # nothing else can start a game.
    def starts
      raise StartsTaken, "a Cabinet hands out its Starts once" if @starts_taken

      @starts_taken = true
      Starts.new(->(opening, seed) { opening ? start_paused(opening, seed || draw_seed) : start_game(seed || draw_seed) })
    end

    # Starting a game on a Cabinet, from Home, which only what holds its
    # Starts can do (Cabinet#starts). Elsewhere it does nothing.
    class Starts
      def initialize(start) = @start = start

      # A game in play at once, drawn from +seed+, by default one of the
      # cabinet's own (#start_game). Answers the cabinet.
      def game(seed = nil) = @start.call(nil, seed)

      # A game with +dots+ (a Stack) as its first, paused before its
      # clock first runs, for the tutorial to play over (#start_paused).
      # Answers the cabinet.
      def paused(dots, seed = nil) = @start.call(dots, seed)
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener = nil, &block)
      @listeners << (listener || block || raise(ArgumentError, "subscribe needs a listener or a block"))
      self
    end

    def press(x, y) = advance(state.press(self, @game, x, y))
    def update(seconds) = advance(state.update(self, @game, seconds))

    # The game in play or just finished, as it stands (Game::View, which
    # cannot change it), or nil on Home.
    def game = state.game

    # The field a game started now would play on, and the class of
    # screen it would count among.
    def field = sizing.fit(screen)
    def size_class = sizing.size_class(screen)

    # The window changed size. A game in play keeps its dots on screen,
    # and their radius, and the next game starts on the new screen.
    def screen=(screen)
      @screen = screen
      game = @game
      return unless game && (state.is_a?(Playing) || state.is_a?(Paused))

      game.field = Field.new(screen.width, screen.height, game.field.radius)
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
      @game = nil
      announce(Events::HomeShown.new(score_record: score_record.of(size_class)))
      Home.new
    end

    # Whether a game is in play (Playing).
    def playing? = state.is_a?(Playing)

    # A press on the paused game, which only the tutorial makes: the rules
    # hear it as in play, and the event comes back to the tutorial alone.
    # Nil when no game is paused.
    def press_paused(x, y) = (@game&.tap_at(x, y) if paused?)

    # Moves the paused game's dots +seconds+ on, at the tutorial's pace;
    # its clock stays as it is.
    def move_paused(seconds)
      @game&.move_dots(seconds) if paused?
    end

    # Puts +dots+ in the paused game in place of the dots of their ids
    # (Game#arrange), as the tutorial shows them.
    def arrange(*dots)
      @game&.arrange(*dots) if paused?
    end

    # Play begins on the paused game, as it is: it is announced as begun,
    # and its clock runs from the next update. It counts among the
    # records of the class of screen it was made on.
    def unpause
      state = self.state
      game = @game
      return self unless state.is_a?(Paused) && game

      advance(begin_game(game, state.seed, state.size_class, tutorial: true))
    end

    # The game's score counts among the records of +size_class+, the class
    # it started in, even if the window changed size meanwhile. +tutorial+
    # says the tutorial played over its opening (#start_paused).
    def finish(game, seed, size_class, tutorial)
      first = score_record.first?(size_class)
      new_score_record = score_record.record(game.score, size_class)
      announce(Events::GameEnded.new(score_record: score_record.of(size_class), new_score_record:, seed:, size_class:, first:,
                                     field: game.field, dots: game.dots, score: game.score, elapsed: game.elapsed, tutorial:))
      GameOver.new(game: game.view, new_score_record:)
    end

    private

    # From Home, a game drawn from +seed+, in play at once (Starts#game).
    # The game gets a Random of its
    # own from its seed, and draws from it only when a dot spawns, so the
    # same seed and the same taps give the same dots, whatever else uses
    # randomness meanwhile. Elsewhere it does nothing.
    def start_game(seed)
      return self unless state.is_a?(Home)

      advance(begin_game(@game = Game.new(field, random: Random.new(seed)), seed))
    end

    # From Home, a game made as #start_game makes one, with +dots+ (a
    # Stack) as its first, paused before its clock first runs, for the
    # tutorial to play over (Paused; Starts#paused). Nothing is announced: its events
    # are the tutorial's until play begins (#unpause).
    def start_paused(dots, seed)
      return self unless state.is_a?(Home)

      game = @game = Game.new(field, random: Random.new(seed), dots:)
      advance(Paused.new(game: game.view, seed:, size_class:))
    end

    # A seed of the game's own randomness, for a game started with none.
    def draw_seed = @random.rand(LARGEST_SEED)

    def begin_game(game, seed, size_class = self.size_class, tutorial: false)
      announce(Events::GameStarted.new(seed:, field: game.field, dots: game.dots, score: game.score, dots_in_a_row: game.dots_in_a_row))
      Playing.new(game: game.view, seed:, size_class:, tutorial:)
    end

    def advance(next_state)
      @state = next_state
      self
    end

    # Each state holds the game's Game::View (+game+), and is handed the
    # game itself (+live+) only as the cabinet passes on a press or an
    # update.

    # Waiting to start. A press here reaches no rule: a game begins only
    # when it is started (Starts).
    class Home < Data.define
      def game = nil
      def press(_cabinet, _live, _x, _y) = self
      def update(_cabinet, _live, _seconds) = self
    end

    # A game in progress. It ends the moment the clock reaches zero,
    # whether time ran out or a penalty took the last of it. +tutorial+
    # says the tutorial played over its opening, while it was Paused.
    class Playing < Data.define(:game, :seed, :size_class, :tutorial)
      def press(cabinet, live, x, y)
        return self unless live

        cabinet.announce(live.tap_at(x, y))
        settle(cabinet, live)
      end

      def update(cabinet, live, seconds)
        return self unless live

        live.update(seconds)
        settle(cabinet, live)
      end

      private

      def settle(cabinet, live) = live.over? ? cabinet.finish(live, seed, size_class, tutorial) : self
    end

    # A game made but not yet begun: its clock has not run, and while the
    # tutorial plays over it, no press reaches it but the ones the
    # tutorial passes on (Cabinet#press_paused), and its dots move only
    # as the tutorial moves them (Cabinet#move_paused).
    class Paused < Data.define(:game, :seed, :size_class)
      def press(_cabinet, _live, _x, _y) = self
      def update(_cabinet, _live, _seconds) = self
    end

    # The game is over and its score is shown. Presses are ignored for a
    # moment so a last frantic tap does not skip it; after that, a press
    # goes back to Home.
    class GameOver < Data.define(:game, :new_score_record, :shown)
      def initialize(game:, new_score_record:, shown: 0.0) = super

      def score = game.score
      def ready? = shown >= Rules::GAME_OVER_GRACE

      def press(cabinet, _live, _x, _y) = ready? ? cabinet.show_home : self
      def update(_cabinet, _live, seconds) = with(shown: shown + seconds)
    end
  end
end
