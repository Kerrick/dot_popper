# frozen_string_literal: true

require "test_helper"

class GoalStreakTest < Minitest::Test
  GoalStreak = DotPopper::GoalStreak

  def day(number) = Date.new(2026, 11, number)

  def test_days_in_a_row_count_up
    streak = GoalStreak.new.meet(day(3)).meet(day(4)).meet(day(5))

    assert_equal 3, streak.current
    assert_equal 3, streak.longest
    assert streak.done_on?(day(5))
  end

  def test_meeting_it_twice_in_a_day_counts_once
    assert_equal 1, GoalStreak.new.meet(day(3)).meet(day(3)).current
  end

  def test_a_missed_day_starts_again_and_the_longest_keeps
    streak = GoalStreak.new.meet(day(1)).meet(day(2)).meet(day(3)).meet(day(5))

    assert_equal 1, streak.current
    assert_equal 3, streak.longest
  end

  def test_the_streak_stands_through_the_next_day_and_not_after
    streak = GoalStreak.new.meet(day(3)).meet(day(4))

    assert_equal 2, streak.current_on(day(4))
    assert_equal 2, streak.current_on(day(5)), "today's goal can still be met"
    assert_equal 0, streak.current_on(day(6))
    assert_equal 0, GoalStreak.new.current_on(day(6))
  end
end
