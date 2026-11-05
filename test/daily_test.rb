# frozen_string_literal: true

require "test_helper"

class DailyTest < Minitest::Test
  include DotPopperTest
  Mode = DotPopper::Mode
  DAY = Date.new(2026, 11, 5)

  def test_a_days_seed_is_fixed_and_differs_from_the_next_days
    assert_equal Mode.daily(DAY).seed, Mode.daily(Date.new(2026, 11, 5)).seed
    refute_equal Mode.daily(DAY).seed, Mode.daily(DAY + 1).seed
    assert_equal 1_443_863_102, Mode.seed_for(DAY), "the seed must never change, or yesterday's results stop comparing"
  end

  def test_the_same_day_and_the_same_taps_give_everyone_the_same_dots
    one = daily_game(Random.new(1))
    other = daily_game(Random.new(2)) # the games' own randomness differs

    12.times do |step|
      one.update(0.37)
      other.update(0.37)
      x, y = tap_for(one.round, step)
      one.press(x, y)
      other.press(x, y)
      assert_equal one.round.dots.to_a, other.round.dots.to_a
      assert_equal one.round.score, other.round.score
    end
  end

  def test_daily_is_chosen_only_on_the_title
    game = DotPopper::Game.new(field)
    game.choose(Mode.daily(DAY))
    assert game.state.mode.daily?

    game.choose(Mode.daily(DAY + 1))
    assert_equal DAY, game.state.mode.date, "a round in play is not interrupted"
  end

  def test_a_press_on_the_title_still_starts_a_free_round
    game = DotPopper::Game.new(field)
    game.press(0, 0)

    refute game.state.mode.daily?
  end

  def test_each_day_keeps_its_own_best
    store = DotPopper::BestScore::Memory.new
    best = DotPopper::DailyBest.new(store)

    assert best.record(DAY, 5)
    refute best.record(DAY, 5)
    assert best.record(DAY, 7)
    assert_equal 7, DotPopper::DailyBest.new(store).value(DAY)
    assert_nil best.value(DAY + 1)
    assert best.record(DAY + 1, 1)
  end

  def test_a_daily_round_ending_reports_the_days_best
    game = DotPopper::Game.new(field)
    heard = []
    game.subscribe { heard << it }
    game.choose(Mode.daily(DAY))
    game.update(20)

    assert_equal 0, heard.last.daily_best
    assert heard.last.new_daily_best
  end

  def test_an_unreadable_daily_best_is_none
    assert_nil DotPopper::DailyBest.new(DotPopper::BestScore::Memory.new("garbage")).value(DAY)
  end

  private

  def daily_game(random)
    DotPopper::Game.new(field, random:).tap { it.choose(Mode.daily(DAY)) }
  end

  # Alternately the fresh dot, and a popped one, the way a player might.
  def tap_for(round, step)
    target = step.odd? ? round.dots.find(&:popped?) : round.dots.find(&:fresh?)
    target ? [target.x, target.y] : [0, 0]
  end
end
