# frozen_string_literal: true

require "test_helper"

class DailyGoalTest < Minitest::Test
  DailyGoal = DotPopper::DailyGoal
  GameStats = DotPopper::GameStats

  def goal(kind) = DailyGoal::LIST.find { it.kind == kind }

  def test_a_date_always_picks_the_same_goal
    day = Date.new(2026, 11, 5)

    assert_equal DailyGoal.for(day), DailyGoal.for(Date.iso8601("2026-11-05"))
    assert_equal 0x6d1e1b30, DailyGoal.fnv("2026-11-05"), "the hash must never change, or a day's goal would"
  end

  def test_a_year_of_days_uses_every_goal_and_favors_none
    year = (Date.new(2026, 1, 1)..Date.new(2026, 12, 31)).map { DailyGoal.for(it) }
    counts = year.tally

    assert_equal DailyGoal::LIST.size, counts.size
    assert_operator counts.values.min, :>=, 365 / DailyGoal::LIST.size / 2
  end

  def test_each_goal_is_judged_from_one_games_stats
    stats = GameStats.start.with(most_dots_in_a_row: 15, times_to_pop: [3.0] + ([0.5] * 9), duration: 50.0, mistakes: 1, score: 30)

    DailyGoal::LIST.reject { it.kind == :clean_game }.each { assert it.met?(stats), it.to_s }
    refute goal(:clean_game).met?(stats)
    assert goal(:clean_game).met?(stats.with(mistakes: 0, score: 10))
  end

  def test_each_goal_falls_short_just_below_its_target
    short = GameStats.start.with(most_dots_in_a_row: 14, times_to_pop: [2.99] + ([1.2] * 8), duration: 49.9, mistakes: 0, score: 29)

    DailyGoal::LIST.reject { it.kind == :clean_game }.each { refute it.met?(short), it.to_s }
    refute goal(:comeback).met?(short.with(score: 40)), "a comeback needs a wrong tap"
  end

  def test_its_name_in_the_log
    assert_equal "clean_run_15", goal(:clean_run).to_s
  end
end
