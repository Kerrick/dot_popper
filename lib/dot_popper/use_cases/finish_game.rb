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
    #
    # It hears the rules' events itself (Cabinet#subscribe, which the
    # composition root does), so what it finishes with comes from the
    # rules alone: the game's numbers (GameStats::Recorder), the
    # achievements its play earned (AchievementRecorder), and whether the
    # tutorial opened it (Events::GameEnded#tutorial).
    class FinishGame
      # What Game Over shows of what the game did: +record+, the most
      # impressive record it set in its class (Stats::Record), or nil;
      # +goal_met+, whether it met today's goal; and +achievements+, those
      # first earned in it that the player may see.
      Result = Data.define(:record, :goal_met, :achievements)

      # A game finished, as its listeners are told: +ended+, the rules'
      # Events::GameEnded; +stats+, its numbers (GameStats); and +result+,
      # what Game Over shows of it (Result).
      Finished = Data.define(:ended, :stats, :result)

      def initialize(stats_book:, achievements:, entitlement:, friend_groups:)
        @stats_book = stats_book
        @achievements = achievements
        @entitlement = entitlement
        @friend_groups = friend_groups
        @recorder = GameStats::Recorder.new
        @achievement_recorder = AchievementRecorder.new
        @listeners = []
      end

      # Adds a listener, told each game as it is finished (Finished): what
      # shows Game Over, which so hears it only once the game is finished.
      def subscribe(listener)
        @listeners << listener
        self
      end

      # The numbers of the game in play, or of the one just finished.
      def stats = @recorder.stats

      # Hears one of the rules' events: each counts toward the game's
      # numbers and its achievements, and GameEnded finishes it.
      def call(event)
        @recorder.call(event)
        @achievement_recorder.call(event)
        return unless event.is_a?(Events::GameEnded)

        result = finish(event, stats:, earned: @achievement_recorder.earned)
        finished = Finished.new(ended: event, stats:, result:)
        @listeners.each { it.call(finished) }
      end

      # +ended+ is the game's Events::GameEnded, +stats+ its numbers
      # (GameStats), and +earned+ the achievements its play earned. A game
      # the tutorial opened never counts in a friend group; any other does,
      # whatever its dot size.
      def finish(ended, stats:, earned: [])
        recorded = @stats_book.record(stats, ended.size_class)
        @friend_groups.game_finished(score: ended.score, counts: !ended.tutorial)
        fresh = @achievements.award(earned, day: @stats_book.today.iso8601)
        pro = @entitlement.pro?
        @friend_groups.report_achievements(fresh) if pro
        Result.new(record: recorded.records.first, goal_met: recorded.goal_met, achievements: pro ? fresh : [])
      end
    end
  end
end
