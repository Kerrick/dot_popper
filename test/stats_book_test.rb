# frozen_string_literal: true

require "test_helper"

class StatsBookTest < Minitest::Test
  StatsBook = DotPopper::StatsBook
  GameStats = DotPopper::GameStats
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def setup
    @store = DotPopper::ScoreRecord::Memory.new
    @stats_book = StatsBook.new(@store, today: -> { Date.new(2026, 11, 5) })
  end

  def test_a_game_is_added_and_saved_on_todays_date
    @stats_book.record(GameStats.start.with(score: 4, dots_popped: 4, duration: 14.0), MEDIUM)

    saved = StatsBook.new(@store).stats
    assert_equal 1, saved.games
    assert_equal "2026-11-05", saved.last_day
    assert_equal [4], saved.recent
  end

  def test_it_returns_the_stats_a_game_set
    @stats_book.record(GameStats.start.with(most_dots_in_a_row: 3, duration: 10.0), MEDIUM)

    assert_equal %i[most_dots_in_a_row longest_game],
                 @stats_book.record(GameStats.start.with(most_dots_in_a_row: 5, duration: 20.0), MEDIUM).records.map(&:kind)
  end

  # 2026-11-03's goal is to score 30 points in one game.
  def test_the_first_game_to_meet_todays_goal_says_so_and_adds_a_day_to_the_streak
    day = Date.new(2026, 11, 3)
    stats_book = StatsBook.new(@store, today: -> { day })
    assert_equal :score, stats_book.goal.kind

    refute stats_book.record(GameStats.start.with(score: 29), MEDIUM).goal_met
    refute stats_book.goal_done?
    assert stats_book.record(GameStats.start.with(score: 30), MEDIUM).goal_met
    assert stats_book.goal_done?
    refute stats_book.record(GameStats.start.with(score: 35), MEDIUM).goal_met, "it is met only once a day"
    assert_equal 1, stats_book.streak
    assert_equal 1, StatsBook.new(@store, today: -> { day }).streak, "the streak is saved"
  end

  def test_the_streak_counts_days_in_a_row_and_a_missed_day_starts_it_again
    days = { Date.new(2026, 11, 3) => :score, Date.new(2026, 11, 8) => :score, Date.new(2026, 11, 12) => :score }
    days.each_key do |day|
      StatsBook.new(@store, today: -> { day }).record(GameStats.start.with(score: 30), MEDIUM)
    end
    later = StatsBook.new(@store, today: -> { Date.new(2026, 11, 13) })

    assert_equal 1, later.streak
    assert_equal 1, later.stats.streak.longest
  end

  def test_an_older_file_is_given_to_this_screens_class_and_saved_again_at_once
    store = DotPopper::ScoreRecord::Memory.new("games=3\nlongest_game=20.0\nmost_dots_in_a_row=5\n")
    small = DotPopper::SizeClass::SMALL
    stats_book = StatsBook.new(store, legacy: small)

    assert_equal 5, stats_book.stats.records_in(small).most_dots_in_a_row
    assert_includes store.read, "small.most_dots_in_a_row=5\n"
    assert_equal 5, StatsBook.new(store, legacy: MEDIUM).stats.records_in(small).most_dots_in_a_row
  end

  def test_a_store_holding_nonsense_starts_from_nothing
    assert_equal DotPopper::Stats.new, StatsBook.new(DotPopper::ScoreRecord::Memory.new("\xFF\xFE".b)).stats
  end
end
