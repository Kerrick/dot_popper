# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Finishing a game: Stats and achievements are kept for anyone, and what
# Game Over shows and friend groups hear of an achievement is Pro's.
class FinishGameTest < Minitest::Test
  include DotPopperTest
  Memory = DotPopper::ScoreRecord::Memory

  # Friend groups as a local fake: what they were told.
  class Groups
    attr_reader :games, :achievements

    def initialize
      @games = []
      @achievements = []
    end

    def game_finished(score:, sized_to_screen:) = @games << [score, sized_to_screen]
    def report_achievements(ids) = @achievements << ids
  end

  def setup
    @stats_book = DotPopper::StatsBook.new(Memory.new, today: -> { Date.new(2026, 11, 13) })
    @achievements = DotPopper::Achievements.new(Memory.new)
    @entitlement = DotPopper::Entitlement.new
    @groups = Groups.new
    @finish = DotPopper::UseCases::FinishGame.new(stats_book: @stats_book, achievements: @achievements, entitlement: @entitlement,
                                                  friend_groups: @groups)
  end

  def test_the_game_goes_into_stats
    @finish.call(ended, stats: stats(dots_popped: 3))

    assert_equal 1, @stats_book.stats.games
    assert_equal 3, @stats_book.stats.dots_popped
  end

  def test_game_over_names_the_most_impressive_record_the_game_set
    assert_nil @finish.call(ended, stats: stats(most_dots_in_a_row: 2)).record, "a first game has nothing to beat"

    result = @finish.call(ended, stats: stats(most_dots_in_a_row: 5))
    assert_equal :most_dots_in_a_row, result.record.kind
    assert_equal 5, result.record.value
  end

  def test_a_free_players_achievements_are_kept_but_not_shown_or_reported
    result = @finish.call(ended, stats: stats, earned: %i[big_score])

    assert_empty result.achievements
    assert @achievements.earned?(:big_score)
    assert_equal "2026-11-13", @achievements.day(:big_score)
    assert_empty @groups.achievements
  end

  def test_a_pro_player_sees_and_reports_only_those_first_earned_in_this_game
    @finish.call(ended, stats: stats, earned: %i[big_score])
    pro = DotPopper::UseCases::FinishGame.new(stats_book: @stats_book, achievements: @achievements, entitlement: DotPopper::Entitlement.new(forced: true),
                                              friend_groups: @groups)
    result = pro.call(ended, stats: stats, earned: %i[big_score blink])

    assert_equal %i[blink], result.achievements
    assert_equal [%i[blink]], @groups.achievements
  end

  def test_only_a_game_with_dots_sized_to_the_screen_and_no_tutorial_counts_in_a_friend_group
    @finish.call(ended(score: 4), stats: stats)
    @finish.call(ended(score: 5), stats: stats, tutorial: true)
    @finish.call(ended(score: 6, size_class: DotPopper::SizeClass::SMALL), stats: stats)

    assert_equal [[4, true], [5, false], [6, false]], @groups.games
  end

  private

  def ended(score: 3, size_class: DotPopper::SizeClass::FITTED)
    DotPopper::Events::GameEnded.new(score_record: score, new_score_record: false, seed: 1, size_class:, field:, dots: DotPopper::Stack.new,
                                     score:, elapsed: 10.0)
  end

  def stats(**) = DotPopper::GameStats.start.with(duration: 10.0, **)
end
