# frozen_string_literal: true

module DotPopper
  module UseCases
    # Finishing a game, as its clock reaches zero: its numbers go into
    # Stats (+stats_book+, StatsBook), with the records it set and today's
    # goal; the achievements its play earned are kept (+achievements+,
    # Achievements), by anyone; and the player's friend groups
    # (+friend_groups+, Groups::Session) hear of a game that counts. A new
    # achievement is shown at Game Over, and reported to friend groups,
    # only for a player with Pro (+entitlement+, Entitlement); a Free
    # player's is kept and shown once Pro is bought. The score record is
    # Cabinet's own, judged as the game ends (Events::GameEnded).
    class FinishGame
      # What Game Over shows of what the game did: +record+, the most
      # impressive record it set in its class (Stats::Record), or nil;
      # +goal_met+, whether it met today's goal; and +achievements+, those
      # first earned in it that the player may see.
      Result = Data.define(:record, :goal_met, :achievements)

      def initialize(stats_book:, achievements:, entitlement:, friend_groups:)
        @stats_book = stats_book
        @achievements = achievements
        @entitlement = entitlement
        @friend_groups = friend_groups
      end

      # +ended+ is the game's Events::GameEnded, +stats+ its numbers
      # (GameStats), and +earned+ the achievements its play earned
      # (AchievementWatch#earned). +tutorial+ says the tutorial played over
      # its opening, so it never counts in a friend group; nor does a game
      # with standard dots.
      def call(ended, stats:, earned: [], tutorial: false)
        recorded = @stats_book.record(stats, ended.size_class)
        @friend_groups.game_finished(score: ended.score, sized_to_screen: ended.size_class == SizeClass::FITTED && !tutorial)
        fresh = @achievements.award(earned, day: @stats_book.today.iso8601)
        pro = @entitlement.pro?
        @friend_groups.report_achievements(fresh) if pro
        Result.new(record: recorded.records.first, goal_met: recorded.goal_met, achievements: pro ? fresh : [])
      end
    end
  end
end
