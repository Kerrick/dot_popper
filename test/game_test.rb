# frozen_string_literal: true

require "test_helper"

class GameTest < Minitest::Test
  include DotPopperTest
  Events = DotPopper::Events

  def test_a_game_starts_with_one_bright_dot_no_score_and_ten_seconds
    game = DotPopper::Game.new(field, random: Random.new(1))

    assert_equal 1, game.dots.size
    assert game.dots.first.bright?
    assert_equal 0, game.score
    assert_equal 10.0, game.countdown.remaining
    refute game.over?
  end

  def test_popping_a_bright_dot_scores_a_point_adds_a_second_and_spawns_a_dot_underneath
    target = dot(400, 300)
    game = game_with(target)

    event = game.tap_at(410, 290)

    assert_instance_of Events::Popped, event
    assert_equal 1, game.score
    assert_in_delta 11.0, game.countdown.remaining
    assert_equal 2, game.dots.size
    top, bottom = game.dots.to_a
    assert_equal target.id, top.id, "the popped dot stays on top"
    assert top.popped?
    assert_equal event.spawned, bottom, "the new dot goes underneath"
    assert bottom.bright?
    assert_equal top, event.dot
    assert_equal [1, 1.0], [event.points, event.seconds]
  end

  def test_tapping_a_popped_dot_costs_two_points_and_two_seconds
    game = game_with(dot(400, 300, popped: true))
    score!(game, 5)

    event = game.tap_at(400, 300)

    assert_instance_of Events::Penalized, event
    assert_equal 3, game.score
    assert_in_delta 8.0, game.countdown.remaining
    assert_equal [-2, -2.0], [event.points, event.seconds]
    refute event.softened?
  end

  def test_the_score_never_goes_below_zero
    game = game_with(dot(400, 300, popped: true))
    score!(game, 1)

    first = game.tap_at(400, 300)
    second = game.tap_at(400, 300)

    assert_equal 0, game.score
    assert_equal(-1, first.points)
    assert_equal 0, second.points
    assert first.softened?
    assert_in_delta 6.0, game.countdown.remaining, 1e-9, "time is still lost"
  end

  def test_tapping_empty_space_does_nothing
    game = game_with(dot(400, 300))

    event = game.tap_at(100, 100)

    assert_instance_of Events::Missed, event
    assert_equal 0, game.score
    assert_equal 10.0, game.countdown.remaining
    assert game.dots.first.bright?
  end

  def test_a_tap_on_overlapping_dots_reaches_only_the_topmost
    game = game_with(dot(400, 300, popped: true), dot(410, 300))

    event = game.tap_at(405, 300)

    assert_instance_of Events::Penalized, event
    assert game.dots.to_a.last.bright?, "the tap does not pass through"
  end

  def test_a_bright_dot_out_from_under_the_popped_ones_can_be_popped
    game = game_with(dot(400, 300, popped: true), dot(480, 300))

    assert_instance_of Events::Popped, game.tap_at(520, 300)
    assert game.dots.to_a[1].popped?
  end

  def test_a_bright_dot_on_top_of_a_popped_one_is_the_one_tapped
    game = game_with(dot(400, 300), dot(400, 300, popped: true))

    assert_instance_of Events::Popped, game.tap_at(400, 300)
  end

  def test_each_new_dot_spawns_under_all_the_others
    game = game_with(dot(400, 300))
    first = game.tap_at(400, 300).spawned
    clear_around!(game, first)
    second = game.tap_at(first.x, first.y).spawned

    assert_equal [first.id, second.id], game.dots.to_a.last(2).map(&:id)
    assert_equal 3, game.dots.map(&:id).uniq.size, "every dot has its own id"
  end

  def test_time_runs_down_and_dots_move_with_each_update
    game = game_with(dot(400, 300, velocity_x: 60))

    game.update(0.5)

    assert_in_delta 9.5, game.countdown.remaining
    assert_in_delta 430, game.dots.first.x
  end

  def test_the_game_ends_when_the_clock_reaches_zero_and_shows_zero
    game = game_with(dot(400, 300))

    game.update(10.4)

    assert game.over?
    assert_equal 0, game.countdown.whole_seconds
  end

  def test_a_penalty_can_end_the_game
    game = game_with(dot(400, 300, popped: true))
    game.update(8.5)

    game.tap_at(400, 300)

    assert game.over?
    assert_equal 0.0, game.countdown.remaining
  end

  def test_nothing_happens_once_the_game_is_over
    game = game_with(dot(400, 300, velocity_x: 60))
    game.update(11)
    resting = game.dots.first

    assert_nil game.tap_at(resting.x, resting.y)
    game.update(1)
    assert_equal resting, game.dots.first
    assert_equal 0, game.score
  end

  def test_moving_the_dots_runs_no_clock
    game = game_with(dot(400, 300, velocity_x: 60), random: Random.new(1))
    game.move_dots(0.5)

    assert_in_delta 430.0, game.dots.first.x
    assert_equal [10.0, 0.0], [game.countdown.remaining, game.elapsed]
  end

  def test_arranging_puts_dots_in_place_of_their_ids_at_the_same_depth
    top = dot(400, 300, popped: true, id: 0)
    under = dot(420, 300, id: 1)
    game = game_with(top, under)
    game.arrange(under.with(x: 600.0, velocity_y: 60.0), top.with(velocity_y: -60.0))

    assert_equal [[0, 400.0, -60.0], [1, 600.0, 60.0]], game.dots.map { [it.id, it.x, it.velocity_y] }
    assert_equal [0, 10.0], [game.score, game.countdown.remaining]
  end

  def test_resizing_keeps_every_dot_on_screen
    game = game_with(dot(780, 590))

    game.field = field(400, 300)

    assert_equal [350.0, 250.0], [game.dots.first.x, game.dots.first.y]
  end

  # Turning a tall phone and back leaves the dots where they were, not
  # bunched into the narrow side (the iPhone playtest).
  def test_turning_keeps_each_dot_where_it_was_in_proportion
    portrait = field(375, 812)
    landscape = field(812, 375)
    near_corner = dot(50 + (0.7 * 275), 50 + (0.2 * 712), velocity_x: 60, velocity_y: -90)
    game = DotPopper::Game.new(portrait, random: Random.new(1), dots: DotPopper::Stack.new([near_corner]))

    game.field = landscape
    turned = game.dots.first

    assert_in_delta 50 + (0.7 * 712), turned.x, 1e-9, "70% across stays 70% across"
    assert_in_delta 50 + (0.2 * 275), turned.y, 1e-9
    assert_equal [60.0, -90.0], [turned.velocity_x, turned.velocity_y], "velocities stay in radii per second"

    game.field = portrait
    back = game.dots.first

    assert_in_delta near_corner.x, back.x, 1e-9, "turning back puts it back"
    assert_in_delta near_corner.y, back.y, 1e-9
  end
end
