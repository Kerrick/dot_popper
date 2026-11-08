# frozen_string_literal: true

require "test_helper"

class TrophyTest < Minitest::Test
  Trophy = DotPopper::Trophy

  def held = Trophy.new(holder: "kai", score: 40, day: 100)

  def test_a_vacant_trophy_goes_to_any_round_that_scores
    assert Trophy.vacant.beaten_by?("sam", 1, 100)
    refute Trophy.vacant.beaten_by?("sam", 0, 100)
  end

  def test_the_holders_score_falls_a_point_a_day
    assert_equal 40, held.standing(100)
    assert_equal 37, held.standing(103)
  end

  def test_the_score_never_falls_below_zero
    assert_equal 0, held.standing(500)
  end

  def test_a_day_before_the_trophy_was_taken_does_not_raise_its_score
    assert_equal 40, held.standing(98)
  end

  def test_beating_the_standing_score_takes_it
    assert held.beaten_by?("sam", 38, 103)
    refute held.beaten_by?("sam", 37, 103), "a tie does not take it"
  end

  def test_a_holder_never_takes_it_from_themselves
    refute held.beaten_by?("kai", 99, 103)
  end

  def test_taking_it_restarts_the_fall_from_the_thiefs_score
    taken = held.taken_by("sam", 38, 103)

    assert_equal ["sam", 38, 38], [taken.holder, taken.score, taken.standing(103)]
    assert_equal 36, taken.standing(105)
  end

  def test_only_rounds_with_dots_sized_to_the_screen_count
    assert Trophy.counts?(sized_to_screen: true)
    refute Trophy.counts?(sized_to_screen: false)
  end

  def test_a_day_is_a_whole_utc_day
    assert_equal Trophy.day(86_400), Trophy.day(172_799)
    assert_equal 1, Trophy.day(86_400)
  end
end
