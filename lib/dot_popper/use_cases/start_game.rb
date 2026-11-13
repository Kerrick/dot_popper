# frozen_string_literal: true

module DotPopper
  module UseCases
    # Starting a game: Play, and the opening of the tutorial, whose game
    # begins as it opens (ADR-0016). It is the one way into a game, and it
    # spends exactly one free game on each (ADR-0012): with none left, no
    # game starts, and the player is offered Pro instead. A game is
    # Gameplay's (+cabinet+, a Cabinet) and the count of free games
    # Monetization's (+free_games+, FreeGames), so neither knows of the
    # other.
    class StartGame
      def initialize(cabinet:, free_games:)
        @cabinet = cabinet
        @free_games = free_games
      end

      # Whether Play would find no game left to start, and lead to the
      # offer of Pro instead.
      def none_left? = !@free_games.can_play?

      # How many games the player has left, or nil where none are counted
      # (FreeGames#metered?), for Play's word; and how many each day gives.
      def left = (@free_games.left if @free_games.metered?)
      def daily = @free_games.daily

      # Starts a game from Home and spends a free game on it: in play at
      # once, or with +opening+ (a Stack), paused before its clock first
      # runs, with those dots first, for the tutorial to play over.
      # Answers :started; :none_left when the player has no game left, and
      # nothing starts; or :not_home away from Home, where nothing is
      # spent.
      def call(opening = nil)
        return :not_home unless @cabinet.state.is_a?(Cabinet::Home)
        return :none_left unless @free_games.spend!

        opening ? @cabinet.start_paused(opening) : @cabinet.start_game
        :started
      end
    end
  end
end
