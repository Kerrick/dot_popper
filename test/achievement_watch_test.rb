# frozen_string_literal: true

require "test_helper"

class AchievementWatchTest < Minitest::Test
  include DotPopperTest

  Events = DotPopper::Events

  def setup
    @watch = DotPopper::AchievementWatch.new
  end

  # Starts watching +game+, as the game announces it.
  def watch(game)
    @game = game
    @watch.call(Events::GameStarted.new(game:, seed: 1))
    game
  end

  # Taps (x, y) in the game and tells the watch what the rules reported.
  def tap_at(x, y)
    event = @game.tap_at(x, y)
    @watch.call(event) if event
    event
  end

  # Pops the game's fresh dot, with the others cleared out of the way.
  def pop_fresh(after: 0.0)
    @game.update(after) if after.positive?
    fresh = @game.dots.find(&:fresh?)
    clear_around!(@game, fresh)
    tap_at(fresh.x, fresh.y)
  end

  def slip
    popped = @game.dots.find(&:popped?)
    tap_at(popped.x, popped.y)
  end

  def end_game
    @watch.call(Events::GameEnded.new(game: @game, best: @game.score, new_best: false, seed: 1,
                                       size_class: DotPopper::SizeClass::MEDIUM))
  end

  # A game with a popped dot to slip on and a fresh one to pop.
  def open_game
    watch(game_with(dot(100, 100, popped: true), dot(600, 400)))
  end

  # A game whose dot has just been popped, as the rules reported, with
  # the fresh dot that replaced it under a popped one (or, with covered:
  # false, clear of it).
  def covered_spawn(covered: true)
    spawned = dot(covered ? 400 : 700, 300, id: 7)
    gone = dot(100, 100, popped: true, id: 8)
    watch(game_with(dot(400, 300, popped: true), gone, spawned))
    @watch.call(Events::Popped.new(dot: gone, x: 100, y: 100, points: 1, seconds: 1.0, spawned:))
  end

  def test_a_game_with_nothing_done_earns_nothing
    open_game

    assert_empty @watch.earned
  end

  def test_popping_a_dot_with_under_a_tenth_showing_earns_sharpshooter
    covered = dot(400, 300, popped: true)
    watch(game_with(covered, dot(395, 300, id: 7)))

    assert_operator DotPopper::Visibility.of(@game.dots.find(&:fresh?), [covered]), :<, DotPopper::Achievement::SHARP
    assert_instance_of Events::Popped, tap_at(346, 300)
    assert_equal %i[sharpshooter], @watch.earned
  end

  def test_popping_a_dot_with_more_showing_does_not
    watch(game_with(dot(400, 300, popped: true), dot(340, 300, id: 7)))
    tap_at(290, 300)

    assert_empty @watch.earned
  end

  def test_a_dot_just_over_a_tenth_showing_is_not_sharp
    covered = dot(400, 300, popped: true)
    fresh = dot(400 - 9, 300, id: 7)
    watch(game_with(covered, fresh))

    assert_operator DotPopper::Visibility.of(fresh, [covered]), :>=, DotPopper::Achievement::SHARP
    tap_at(fresh.x - 45, 300)
    refute_includes @watch.earned, :sharpshooter
  end

  def test_three_pops_with_under_a_quarter_showing_in_a_game_earn_a_sharp_trio
    stack = [dot(400, 300, popped: true), dot(400, 100, popped: true), dot(400, 500, popped: true),
             dot(390, 300, id: 7), dot(390, 100, id: 8), dot(390, 500, id: 9)]
    watch(game_with(*stack))
    tap_at(341, 300)
    tap_at(341, 100)
    refute_includes @watch.earned, :sharp_trio
    tap_at(341, 500)

    assert_includes @watch.earned, :sharp_trio
  end

  def test_a_dot_waited_for_three_seconds_while_it_was_covered_earns_patience
    covered_spawn
    @game.update(3.5)
    pop_fresh

    assert_equal %i[patience], @watch.earned
  end

  def test_two_seconds_is_not_patience
    covered_spawn
    @game.update(2.5)
    pop_fresh

    assert_empty @watch.earned
  end

  def test_tapping_in_the_meantime_is_not_patience
    covered_spawn
    @game.update(1.0)
    @watch.call(Events::Missed.new(x: 5, y: 5))
    @game.update(2.5)
    pop_fresh

    assert_empty @watch.earned
  end

  def test_a_dot_that_was_never_covered_is_not_patience
    covered_spawn(covered: false)
    @game.update(3.5)
    pop_fresh

    assert_empty @watch.earned
  end

  def test_a_dot_popped_within_four_tenths_of_the_last_earns_blink
    open_game
    pop_fresh
    pop_fresh(after: 0.3)

    assert_equal %i[blink], @watch.earned
  end

  def test_the_first_pop_of_a_game_is_never_a_blink
    open_game
    pop_fresh

    assert_empty @watch.earned
  end

  def test_a_slower_pop_is_not_a_blink
    open_game
    pop_fresh
    pop_fresh(after: 0.5)

    assert_empty @watch.earned
  end

  def test_twenty_pops_in_a_row_earn_steady_and_forty_unshaken
    open_game
    19.times { pop_fresh(after: 0.7) }
    assert_empty @watch.earned
    pop_fresh(after: 0.7)
    assert_equal %i[steady], @watch.earned
    19.times { pop_fresh(after: 0.7) }
    assert_equal %i[steady], @watch.earned
    pop_fresh(after: 0.7)

    assert_equal %i[steady unshaken], @watch.earned
  end

  def test_a_mistake_starts_the_run_again
    open_game
    10.times { pop_fresh(after: 0.5) }
    slip
    refute_includes @watch.earned, :shake_off
    10.times { pop_fresh(after: 0.5) }
    assert_includes @watch.earned, :shake_off
    refute_includes @watch.earned, :steady, "ten and ten are not twenty in a row"
  end

  def test_ten_pops_without_a_mistake_are_not_shaking_one_off
    open_game
    10.times { pop_fresh(after: 0.5) }

    refute_includes @watch.earned, :shake_off
  end

  def test_getting_the_clock_from_two_seconds_back_to_ten_earns_comeback
    open_game
    @game.update(9.2)
    pop_fresh
    3.times { pop_fresh }
    refute_includes @watch.earned, :comeback
    8.times { pop_fresh }

    assert_includes @watch.earned, :comeback
  end

  def test_a_long_clock_that_was_never_short_is_not_a_comeback
    open_game
    12.times { pop_fresh }

    refute_includes @watch.earned, :comeback
  end

  def test_fifteen_pops_in_the_first_ten_seconds_earn_a_fast_start
    open_game
    14.times { pop_fresh(after: 0.4) }
    refute_includes @watch.earned, :fast_start
    pop_fresh(after: 0.4)

    assert_includes @watch.earned, :fast_start
  end

  def test_slower_pops_are_not_a_fast_start
    open_game
    16.times { pop_fresh(after: 0.8) }

    refute_includes @watch.earned, :fast_start
  end

  def test_a_score_of_seventy_five_earns_a_big_score_when_the_game_ends
    open_game
    score!(@game, 75)
    refute_includes @watch.earned, :big_score
    end_game

    assert_includes @watch.earned, :big_score
  end

  def test_a_lower_score_does_not
    open_game
    score!(@game, 74)
    end_game

    refute_includes @watch.earned, :big_score
  end

  def test_a_game_that_lasts_ninety_seconds_earns_a_long_haul
    open_game
    @game.instance_variable_set(:@elapsed, 90.5)
    end_game

    assert_equal %i[long_haul], @watch.earned
  end

  def test_a_new_game_starts_from_nothing
    watch(game_with(dot(400, 300, popped: true), dot(395, 300, id: 7)))
    tap_at(346, 300)
    assert_equal %i[sharpshooter], @watch.earned

    open_game

    assert_empty @watch.earned
  end

  def test_events_before_any_game_are_ignored
    gone = dot(100, 100, popped: true)
    @watch.call(Events::Popped.new(dot: gone, x: 1, y: 1, points: 1, seconds: 1.0, spawned: dot(5, 5)))
    @watch.call(Events::Penalized.new(dot: gone, x: 1, y: 1, points: -2, seconds: -2.0))

    assert_empty @watch.earned
  end

  def test_achievements_are_listed_in_the_order_the_records_screen_lists_them
    open_game
    @game.instance_variable_set(:@elapsed, 95.0)
    score!(@game, 80)
    end_game

    assert_equal %i[big_score long_haul], @watch.earned
  end
end
