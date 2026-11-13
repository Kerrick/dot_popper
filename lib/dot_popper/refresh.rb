# frozen_string_literal: true

module DotPopper
  # When the game asks the server again for what can change while it
  # runs: the themes available, and the player's friend groups. A phone
  # keeps a game's process for days, so asking only at launch left a
  # theme released meanwhile, or a title change, unseen until the
  # process ended.
  #
  # It asks again when the game comes back to the foreground (#came_back,
  # which the shell reports) and when Home is shown after a game (it
  # hears Cabinet's HomeShown), never while a game is in play or the
  # tutorial plays over one, and no sooner than FLOOR after the last ask,
  # launch included. Coming back during a game asks nothing then; Home
  # after that game does. Each of +askers+ makes the same request it makes
  # at launch, so nothing new is sent, only more often.
  #
  # +clock+ answers the time in seconds. It is the wall clock, since the
  # frames' time stands still while the game is away, which is when the
  # most time passes; a clock set back asks at once rather than wait.
  class Refresh
    # The least time between asks, in seconds. The server limits neither
    # request; five minutes keeps a player who switches apps often to a
    # dozen of each an hour at most.
    FLOOR = 300.0
    # What the privacy facts say of each request asked again, after when
    # it is asked at first.
    HAPPENS = "Again when the player returns to the game or to Home after a game, at most every #{Integer(FLOOR / 60)} minutes.".freeze

    def initialize(askers, cabinet:, clock: -> { Time.now.to_f })
      @askers = askers
      @cabinet = cabinet
      @clock = clock
      @asked_at = clock.call
    end

    # The game came back to the foreground.
    def came_back = ask_if_due

    # Hears Cabinet's events: Home shown after a game.
    def call(event)
      ask_if_due if event.is_a?(Events::HomeShown)
    end

    private

    def ask_if_due
      return if @cabinet.playing? || @cabinet.paused?

      now = @clock.call
      elapsed = now - @asked_at
      return if elapsed >= 0 && elapsed < FLOOR

      @asked_at = now
      @askers.each(&:call)
    end
  end
end
