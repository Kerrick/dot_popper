# frozen_string_literal: true

module DotPopper
  module UseCases
    # Looking at achievements: they are Metagame's (+achievements+,
    # Achievements), earned and kept by anyone, and seeing what was
    # earned is Pro's (+entitlement+, Entitlement). A Free player sees how
    # each is earned; Pro also sees which are earned, the day each was,
    # how many, and how far along the four the game measures are, from
    # Stats (+stats_book+, StatsBook) and the score records
    # (+score_record+, ScoreRecord).
    class ViewAchievements
      def initialize(achievements:, entitlement:, stats_book:, score_record:)
        @achievements = achievements
        @entitlement = entitlement
        @stats_book = stats_book
        @score_record = score_record
      end

      # Whether what was earned is held back, as for a Free player, whose
      # dialog leads to Pro instead.
      def locked? = !@entitlement.pro?

      # Whether +id+ shows as earned.
      def earned?(id) = !locked? && @achievements.earned?(id)

      # The day +id+ was earned, or nil, unless locked.
      def day(id) = (@achievements.day(id) unless locked?)

      # How many are earned, or nil while locked.
      def count = (@achievements.count unless locked?)

      # How far along +id+ is, as [record, goal], for the four the game
      # measures (Steady hand, Unshaken, Big score, Long haul) while not yet
      # earned; nil for the rest, and while locked.
      def progress(id)
        return if locked? || @achievements.earned?(id)

        records = @stats_book.stats.records.values
        case id
        when :steady then [most_dots_in_a_row(records), Achievement::STEADY]
        when :unshaken then [most_dots_in_a_row(records), Achievement::UNSHAKEN]
        when :big_score then [SizeClass::ALL.map { @score_record.of(it) }.max || 0, Achievement::BIG_SCORE]
        when :long_haul then [records.map(&:longest_game).max.to_f.round, Achievement::LONG_HAUL.to_i]
        end
      end

      private

      def most_dots_in_a_row(records) = records.map(&:most_dots_in_a_row).max.to_i
    end
  end
end
