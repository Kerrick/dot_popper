# frozen_string_literal: true

require "test_helper"

class GameStatsTest < Minitest::Test
  include DotPopperTest
  Cabinet = DotPopper::Cabinet
  GameStats = DotPopper::GameStats

  def setup
    @cabinet = Cabinet.new(field, random: Random.new(9))
    @recorder = GameStats::Recorder.new
    @cabinet.subscribe(@recorder)
    @cabinet.press(0, 0)
  end

  def test_it_counts_dots_popped_and_times_each_wait_from_the_dot_appearing
    @cabinet.update(1.5)
    pop!
    @cabinet.update(0.5)
    pop!

    stats = @recorder.stats
    assert_equal 2, stats.dots_popped
    assert_equal [1.5, 0.5], stats.times_to_pop.map { it.round(6) }
    assert_in_delta 1.5, stats.longest_time_to_pop
    assert_in_delta 1.0, stats.mean_time_to_pop
  end

  def test_it_counts_mistakes_and_those_the_floor_softened
    pop!
    popped = @cabinet.game.dots.first
    clear_around!(@cabinet.game, popped)
    @cabinet.press(popped.x, popped.y) # 1 point to lose: softened
    @cabinet.press(popped.x, popped.y) # 0 points to lose: softened

    assert_equal 2, @recorder.stats.mistakes
    assert_equal 2, @recorder.stats.softened
  end

  def test_the_game_ending_stats_how_long_it_ran
    @cabinet.update(4)
    pop!
    @cabinet.update(20)

    assert_in_delta 11.0, @recorder.stats.duration
  end

  def test_a_new_game_starts_from_nothing
    pop!
    @cabinet.update(20)
    @cabinet.update(1)
    @cabinet.press(0, 0)
    @cabinet.press(0, 0)

    assert_equal GameStats.start, @recorder.stats
  end

  def test_with_nothing_popped_the_waits_are_zero
    assert_in_delta 0.0, GameStats.start.longest_time_to_pop
    assert_in_delta 0.0, GameStats.start.mean_time_to_pop
  end

  def test_it_keeps_the_score_and_the_most_dots_in_a_row_without_a_mistake
    3.times { pop! }
    mistake!
    pop!

    stats = @recorder.stats
    assert_equal 2, stats.score # 4 dots popped, and a mistake at 3 that cost 2
    assert_equal 1, stats.dots_in_a_row
    assert_equal 3, stats.most_dots_in_a_row
  end

  def test_it_knows_the_shortest_time_to_pop_and_the_dots_popped_in_the_first_seconds
    @cabinet.update(2.0)
    pop!
    @cabinet.update(0.5)
    pop!
    @cabinet.update(8.0)
    pop!

    stats = @recorder.stats
    assert_in_delta 0.5, stats.shortest_time_to_pop
    assert_equal 2, stats.dots_popped_within(10)
    assert_equal 3, stats.dots_popped_within(10.5)
    assert_nil GameStats.start.shortest_time_to_pop
  end

  private

  def mistake!
    popped = @cabinet.game.dots.find(&:popped?)
    clear_around!(@cabinet.game, popped)
    @cabinet.press(popped.x, popped.y)
  end

  def pop!
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(@cabinet.game, bright)
    @cabinet.press(bright.x, bright.y)
  end
  # The tutorial's game: two dots popped and the guide's mistake while it is
  # paused, heard by the rules but announced to no one, then play.
  def test_a_game_the_tutorial_played_over_counts_its_dots_popped_without_a_wait_and_no_mistake
    cabinet = Cabinet.new(field, random: Random.new(9))
    recorder = GameStats::Recorder.new
    cabinet.subscribe(recorder)
    cabinet.start_paused(DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    cabinet.press_paused(300, 300)
    cabinet.press_paused(300, 300)
    spawned = cabinet.game.dots.to_a.last
    clear_around!(cabinet.game, spawned)
    cabinet.press_paused(spawned.x, spawned.y)
    cabinet.unpause

    stats = recorder.stats
    assert_equal [2, 0, 1, 1, 1], [stats.dots_popped, stats.mistakes, stats.score, stats.dots_in_a_row, stats.most_dots_in_a_row]
    assert_empty stats.times_to_pop
    assert_nil stats.shortest_time_to_pop

    cabinet.update(1.5)
    bright = cabinet.game.dots.to_a.last
    clear_around!(cabinet.game, bright)
    cabinet.press(bright.x, bright.y)
    assert_equal [3, 2, 2], [recorder.stats.dots_popped, recorder.stats.score, recorder.stats.most_dots_in_a_row], "the row is the game's own"
    assert_equal [1.5], recorder.stats.times_to_pop.map { it.round(6) }, "the first wait runs from the clock starting"
  end
end
