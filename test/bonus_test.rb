# frozen_string_literal: true

require "test_helper"

# The streak's bonus dot (Rules::BONUS): earned by pops in a row, never by
# chance, in place of the next fresh dot, paid on top of a pop.
class BonusTest < Minitest::Test
  include DotPopperTest
  Events = DotPopper::Events
  Rules = DotPopper::Rules

  def test_the_numbers_are_a_streak_a_payoff_in_points_and_a_payoff_in_seconds
    assert_equal [8, 3, 3.0], [Rules::BONUS.streak, Rules::BONUS.points, Rules::BONUS.seconds]
  end

  # A round on a field so wide that its dots, which never move here,
  # rarely cover one another, so each fresh dot can be popped on the spot.
  def calm_round(**) = DotPopper::Round.new(field(4000, 3000), random: Random.new(3), **)

  def pop_next(round)
    fresh = round.dots.find(&:fresh?)
    round.tap_at(fresh.x, fresh.y)
  end

  def test_a_round_has_no_bonus_dot_before_a_streak
    round = calm_round
    events = Array.new(Rules::BONUS.streak - 1) { pop_next(round) }

    assert(events.none? { it.spawned.bonus? })
    assert_equal Rules::BONUS.streak - 1, round.streak
  end

  def test_the_pop_that_completes_the_streak_spawns_a_bonus_dot_in_place_of_the_ordinary_one
    round = calm_round
    events = Array.new(Rules::BONUS.streak) { pop_next(round) }

    assert events.last.spawned.bonus?
    assert events.last.spawned.fresh?
    assert_equal events.size + 1, round.dots.size, "one new dot, not two"
    assert_equal 1, round.dots.count(&:fresh?), "still one bright dot to pop"
    assert_equal [events.last.spawned], round.dots.select(&:bonus?)
    assert_equal 0, round.streak, "the count starts over once a bonus dot is earned"
  end

  def test_popping_the_bonus_dot_pays_its_points_and_seconds_on_top_of_a_pops_own
    round = calm_round
    Rules::BONUS.streak.times { pop_next(round) }
    score = round.score
    left = round.countdown.remaining

    event = pop_next(round)

    assert event.dot.bonus?
    assert_equal Rules::POP_POINTS + Rules::BONUS.points, event.points
    assert_equal Rules::POP_SECONDS + Rules::BONUS.seconds, event.seconds
    assert_equal score + event.points, round.score
    assert_in_delta left + event.seconds, round.countdown.remaining
    refute event.spawned.bonus?, "the next bright dot is an ordinary one"
  end

  def test_a_wrong_tap_starts_the_count_over
    round = calm_round
    (Rules::BONUS.streak - 1).times { pop_next(round) }
    popped = round.dots.find(&:popped?)

    assert_instance_of Events::Penalized, round.tap_at(popped.x, popped.y)

    assert_equal 0, round.streak
    refute pop_next(round).spawned.bonus?, "one more pop would have earned it, had the streak held"
  end

  def test_a_bonus_dot_already_earned_stays_when_the_streak_breaks
    round = calm_round
    Rules::BONUS.streak.times { pop_next(round) }
    bonus = round.dots.find(&:bonus?)
    popped = round.dots.find(&:popped?)

    assert_instance_of Events::Penalized, round.tap_at(popped.x, popped.y)

    assert_equal 0, round.streak
    assert round.dots.find { it.id == bonus.id }.bonus?
    assert_equal Rules::POP_POINTS + Rules::BONUS.points, pop_next(round).points
  end

  def test_popping_a_bonus_dot_does_not_count_toward_the_next_streak
    round = calm_round
    (Rules::BONUS.streak + 1).times { pop_next(round) }

    assert_equal 0, round.streak
    (Rules::BONUS.streak - 1).times { assert_equal false, pop_next(round).spawned.bonus? }
    assert pop_next(round).spawned.bonus?
  end

  def test_the_bonus_never_changes_where_or_how_fast_any_dot_spawns
    with = calm_round
    without = calm_round(bonus: nil)
    ((Rules::BONUS.streak + 1) * 2).times do
      pop_next(with)
      pop_next(without)
    end

    assert_equal without.dots.map { it.with(bonus: false) }, with.dots.map { it.with(bonus: false) }
    refute without.dots.any?(&:bonus?)
    assert_equal 2, with.dots.count(&:bonus?), "two streaks, two bonus dots"
  end

  def test_without_a_bonus_rule_a_streak_earns_nothing
    round = calm_round(bonus: nil)
    events = Array.new(Rules::BONUS.streak * 2) { pop_next(round) }

    assert(events.none? { it.spawned.bonus? })
    assert(events.all? { it.points == Rules::POP_POINTS })
  end

  def test_a_round_resumed_from_the_tutorial_starts_its_streak_at_none
    popped = [dot(300, 300, popped: true), dot(500, 300, popped: true)]
    round = DotPopper::Round.resume(field, dots: DotPopper::Stack.new(dots: popped + [dot(100, 100)]), score: 2,
                                           seconds: 10)

    assert_equal 0, round.streak
  end

  def test_stats_count_the_bonus_dots_popped
    stats = DotPopper::RoundStats.start
    round = calm_round
    (Rules::BONUS.streak + 1).times do
      event = pop_next(round)
      stats = stats.record(event, at: round.elapsed)
    end

    assert_equal 1, stats.bonuses
    assert_equal Rules::BONUS.streak + 1, stats.pops, "a bonus pop is a pop"
    assert_equal Rules::BONUS.streak + 1, stats.longest_run
  end
end
