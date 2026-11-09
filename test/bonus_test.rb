# frozen_string_literal: true

require "test_helper"

# The row's bonus dot (Rules::BONUS): earned by dots in a row, never by
# chance, in place of the next fresh dot, pro on top of a pop.
class BonusTest < Minitest::Test
  include DotPopperTest
  Events = DotPopper::Events
  Rules = DotPopper::Rules

  def test_the_numbers_are_a_dots_in_a_row_a_payoff_in_points_and_a_payoff_in_seconds
    assert_equal [8, 3, 3.0], [Rules::BONUS.dots_in_a_row, Rules::BONUS.points, Rules::BONUS.seconds]
  end

  # A game on a field so wide that its dots, which never move here,
  # rarely cover one another, so each fresh dot can be popped on the spot.
  def calm_game(**) = DotPopper::Game.new(field(4000, 3000), random: Random.new(3), **)

  def pop_next(game)
    fresh = game.dots.find(&:fresh?)
    game.tap_at(fresh.x, fresh.y)
  end

  def test_a_game_has_no_bonus_dot_before_a_dots_in_a_row
    game = calm_game
    events = Array.new(Rules::BONUS.dots_in_a_row - 1) { pop_next(game) }

    assert(events.none? { it.spawned.bonus? })
    assert_equal Rules::BONUS.dots_in_a_row - 1, game.dots_in_a_row
  end

  def test_the_pop_that_completes_the_dots_in_a_row_spawns_a_bonus_dot_in_place_of_the_ordinary_one
    game = calm_game
    events = Array.new(Rules::BONUS.dots_in_a_row) { pop_next(game) }

    assert events.last.spawned.bonus?
    assert events.last.spawned.fresh?
    assert_equal events.size + 1, game.dots.size, "one new dot, not two"
    assert_equal 1, game.dots.count(&:fresh?), "still one bright dot to pop"
    assert_equal [events.last.spawned], game.dots.select(&:bonus?)
    assert_equal 0, game.dots_in_a_row, "the count starts over once a bonus dot is earned"
  end

  def test_popping_the_bonus_dot_pays_its_points_and_seconds_on_top_of_a_pops_own
    game = calm_game
    Rules::BONUS.dots_in_a_row.times { pop_next(game) }
    score = game.score
    left = game.countdown.remaining

    event = pop_next(game)

    assert event.dot.bonus?
    assert_equal Rules::POP_POINTS + Rules::BONUS.points, event.points
    assert_equal Rules::POP_SECONDS + Rules::BONUS.seconds, event.seconds
    assert_equal score + event.points, game.score
    assert_in_delta left + event.seconds, game.countdown.remaining
    refute event.spawned.bonus?, "the next bright dot is an ordinary one"
  end

  def test_a_wrong_tap_starts_the_count_over
    game = calm_game
    (Rules::BONUS.dots_in_a_row - 1).times { pop_next(game) }
    popped = game.dots.find(&:popped?)

    assert_instance_of Events::Penalized, game.tap_at(popped.x, popped.y)

    assert_equal 0, game.dots_in_a_row
    refute pop_next(game).spawned.bonus?, "one more pop would have earned it, had the streak held"
  end

  def test_a_bonus_dot_already_earned_stays_when_the_dots_in_a_row_breaks
    game = calm_game
    Rules::BONUS.dots_in_a_row.times { pop_next(game) }
    bonus = game.dots.find(&:bonus?)
    popped = game.dots.find(&:popped?)

    assert_instance_of Events::Penalized, game.tap_at(popped.x, popped.y)

    assert_equal 0, game.dots_in_a_row
    assert game.dots.find { it.id == bonus.id }.bonus?
    assert_equal Rules::POP_POINTS + Rules::BONUS.points, pop_next(game).points
  end

  def test_popping_a_bonus_dot_does_not_count_toward_the_next_dots_in_a_row
    game = calm_game
    (Rules::BONUS.dots_in_a_row + 1).times { pop_next(game) }

    assert_equal 0, game.dots_in_a_row
    (Rules::BONUS.dots_in_a_row - 1).times { assert_equal false, pop_next(game).spawned.bonus? }
    assert pop_next(game).spawned.bonus?
  end

  def test_the_bonus_never_changes_where_or_how_fast_any_dot_spawns
    with = calm_game
    without = calm_game(bonus: nil)
    ((Rules::BONUS.dots_in_a_row + 1) * 2).times do
      pop_next(with)
      pop_next(without)
    end

    assert_equal without.dots.map { it.with(bonus: false) }, with.dots.map { it.with(bonus: false) }
    refute without.dots.any?(&:bonus?)
    assert_equal 2, with.dots.count(&:bonus?), "two streaks, two bonus dots"
  end

  def test_without_a_bonus_rule_a_dots_in_a_row_earns_nothing
    game = calm_game(bonus: nil)
    events = Array.new(Rules::BONUS.dots_in_a_row * 2) { pop_next(game) }

    assert(events.none? { it.spawned.bonus? })
    assert(events.all? { it.points == Rules::POP_POINTS })
  end

  def test_a_game_resumed_from_the_tutorial_starts_its_dots_in_a_row_at_none
    popped = [dot(300, 300, popped: true), dot(500, 300, popped: true)]
    game = DotPopper::Game.resume(field, dots: DotPopper::Stack.new(dots: popped + [dot(100, 100)]), score: 2,
                                           seconds: 10)

    assert_equal 0, game.dots_in_a_row
  end

  def test_stats_count_the_bonus_dots_popped
    stats = DotPopper::GameStats.start
    game = calm_game
    (Rules::BONUS.dots_in_a_row + 1).times do
      event = pop_next(game)
      stats = stats.record(event, at: game.elapsed)
    end

    assert_equal 1, stats.bonuses
    assert_equal Rules::BONUS.dots_in_a_row + 1, stats.pops, "a bonus pop is a pop"
    assert_equal Rules::BONUS.dots_in_a_row + 1, stats.most_dots_in_a_row
  end
end
