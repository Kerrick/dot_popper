# frozen_string_literal: true

require_relative "../use_cases"

module DotPopper
  module Composition
    # The use cases (ADR-0017), made from the objects of the game's areas
    # that each joins, and subscribed to what each hears, here and nowhere
    # else: FinishGame hears the rules' events, before anything made after
    # it, and BuyPro hears Pro arrive (Entitlement::ProGranted). Answers
    # them by the names Presentation::Show takes. +use_theme+ is made
    # before the rest, since the pen and the sound player take the current
    # theme from it before anything is drawn. +starter+ is the cabinet's
    # one Starter, which StartGame holds.
    def self.use_cases(cabinet:, free_games:, entitlement:, store:, achievements:, stats_book:, friend_groups:, use_theme:,
                       starter: cabinet.starter)
      buy_pro = UseCases::BuyPro.new(store:, entitlement:, cabinet:, achievements:, friend_groups:)
      entitlement.subscribe(buy_pro)
      finish_game = UseCases::FinishGame.new(stats_book:, achievements:, entitlement:, friend_groups:)
      cabinet.subscribe(finish_game)
      {
        start_game: UseCases::StartGame.new(cabinet:, free_games:, starter:),
        finish_game:,
        buy_pro:,
        use_theme:,
        join_or_create_friend_group: UseCases::JoinOrCreateFriendGroup.new(groups: friend_groups, entitlement:),
        view_achievements: UseCases::ViewAchievements.new(achievements:, entitlement:, stats_book:, score_record: cabinet.score_record)
      }
    end
  end
end
