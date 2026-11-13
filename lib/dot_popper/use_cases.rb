# frozen_string_literal: true

module DotPopper
  # What a player does with the game, each as an object the screens call
  # and that calls the game's areas: Gameplay and Metagame (the rules,
  # Stats, records, achievements, friend groups, themes) and Monetization
  # (Free and Pro, free games, the stores). A rule that needs both areas
  # lives here, so the rules of play never know that Pro exists, and no
  # screen decides what Pro allows (ADR-0017). Each takes its
  # collaborators when it is made, and none of it touches Lota.
  module UseCases
  end
end

%w[start_game finish_game].each { require_relative "use_cases/#{it}" }
