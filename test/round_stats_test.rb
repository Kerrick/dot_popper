# frozen_string_literal: true

require "test_helper"

class RoundStatsTest < Minitest::Test
  include DotPopperTest
  Game = DotPopper::Game
  RoundStats = DotPopper::RoundStats

  def setup
    @game = Game.new(field, random: Random.new(9))
    @recorder = RoundStats::Recorder.new
    @game.subscribe(@recorder)
    @game.press(0, 0)
  end

  def test_it_counts_pops_and_times_each_wait_from_the_dot_appearing
    @game.update(1.5)
    pop!
    @game.update(0.5)
    pop!

    stats = @recorder.stats
    assert_equal 2, stats.pops
    assert_equal [1.5, 0.5], stats.waits.map { it.round(6) }
    assert_in_delta 1.5, stats.longest_wait
    assert_in_delta 1.0, stats.mean_wait
  end

  def test_it_counts_slips_and_those_the_floor_softened
    pop!
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @game.press(popped.x, popped.y) # 1 point to lose: softened
    @game.press(popped.x, popped.y) # 0 points to lose: softened

    assert_equal 2, @recorder.stats.slips
    assert_equal 2, @recorder.stats.softened
  end

  def test_the_round_ending_records_how_long_it_ran
    @game.update(4)
    pop!
    @game.update(20)

    assert_in_delta 11.0, @recorder.stats.duration
  end

  def test_a_new_round_starts_from_nothing
    pop!
    @game.update(20)
    @game.update(1)
    @game.press(0, 0)
    @game.press(0, 0)

    assert_equal RoundStats.start, @recorder.stats
  end

  def test_with_nothing_popped_the_waits_are_zero
    assert_in_delta 0.0, RoundStats.start.longest_wait
    assert_in_delta 0.0, RoundStats.start.mean_wait
  end

  private

  def pop!
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @game.press(fresh.x, fresh.y)
  end
end
