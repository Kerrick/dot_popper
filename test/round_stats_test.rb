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

  def test_it_keeps_the_score_and_the_longest_run_of_pops_without_a_wrong_tap
    3.times { pop! }
    slip!
    pop!

    stats = @recorder.stats
    assert_equal 2, stats.score # 4 pops, and a wrong tap at 3 that cost 2
    assert_equal 1, stats.run
    assert_equal 3, stats.longest_run
  end

  def test_it_knows_the_fastest_pop_and_the_pops_in_the_first_seconds
    @game.update(2.0)
    pop!
    @game.update(0.5)
    pop!
    @game.update(8.0)
    pop!

    stats = @recorder.stats
    assert_in_delta 0.5, stats.fastest_pop
    assert_equal 2, stats.pops_within(10)
    assert_equal 3, stats.pops_within(10.5)
    assert_nil RoundStats.start.fastest_pop
  end

  private

  def slip!
    popped = @game.round.dots.find(&:popped?)
    clear_around!(@game.round, popped)
    @game.press(popped.x, popped.y)
  end

  def pop!
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @game.press(fresh.x, fresh.y)
  end
  def test_a_resumed_round_counts_the_pops_it_carries_without_a_wait
    game = Game.new(field, random: Random.new(9))
    recorder = RoundStats::Recorder.new
    game.subscribe(recorder)
    dots = DotPopper::Stack.new(dots: [dot(300, 300, popped: true), dot(340, 300, popped: true), dot(500, 300)])
    game.resume(field: field, dots:, score: 2, seconds: 12.0)

    stats = recorder.stats
    assert_equal [2, 2, 2, 2], [stats.pops, stats.score, stats.run, stats.longest_run]
    assert_empty stats.waits
    assert_nil stats.fastest_pop

    game.update(1.5)
    fresh = game.round.dots.to_a.last
    game.press(fresh.x, fresh.y)
    assert_equal [3, 3, 3], [recorder.stats.pops, recorder.stats.score, recorder.stats.longest_run]
    assert_equal [1.5], recorder.stats.waits.map { it.round(6) }, "the first wait runs from the clock starting"
  end
end
