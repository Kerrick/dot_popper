# frozen_string_literal: true

require "test_helper"

class RoundTest < Minitest::Test
  include DotPopperTest
  Events = DotPopper::Events

  def test_a_round_starts_with_one_fresh_dot_no_score_and_ten_seconds
    round = DotPopper::Round.new(field, random: Random.new(1))

    assert_equal 1, round.dots.size
    assert round.dots.first.fresh?
    assert_equal 0, round.score
    assert_equal 10.0, round.countdown.remaining
    refute round.over?
  end

  def test_popping_a_fresh_dot_scores_a_point_adds_a_second_and_spawns_a_dot_underneath
    target = dot(400, 300)
    round = round_with(target)

    event = round.tap_at(410, 290)

    assert_instance_of Events::Popped, event
    assert_equal 1, round.score
    assert_in_delta 11.0, round.countdown.remaining
    assert_equal 2, round.dots.size
    top, bottom = round.dots.to_a
    assert_equal target.id, top.id, "the popped dot stays on top"
    assert top.popped?
    assert_equal event.spawned, bottom, "the new dot goes underneath"
    assert bottom.fresh?
    assert_equal top, event.dot
    assert_equal [1, 1.0], [event.points, event.seconds]
  end

  def test_tapping_a_popped_dot_costs_two_points_and_two_seconds
    round = round_with(dot(400, 300, popped: true))
    score!(round, 5)

    event = round.tap_at(400, 300)

    assert_instance_of Events::Penalized, event
    assert_equal 3, round.score
    assert_in_delta 8.0, round.countdown.remaining
    assert_equal [-2, -2.0], [event.points, event.seconds]
    refute event.softened?
  end

  def test_the_score_never_goes_below_zero
    round = round_with(dot(400, 300, popped: true))
    score!(round, 1)

    first = round.tap_at(400, 300)
    second = round.tap_at(400, 300)

    assert_equal 0, round.score
    assert_equal(-1, first.points)
    assert_equal 0, second.points
    assert first.softened?
    assert_in_delta 6.0, round.countdown.remaining, 1e-9, "time is still lost"
  end

  def test_tapping_empty_space_does_nothing
    round = round_with(dot(400, 300))

    event = round.tap_at(100, 100)

    assert_instance_of Events::Missed, event
    assert_equal 0, round.score
    assert_equal 10.0, round.countdown.remaining
    assert round.dots.first.fresh?
  end

  def test_a_tap_on_overlapping_dots_reaches_only_the_topmost
    round = round_with(dot(400, 300, popped: true), dot(410, 300))

    event = round.tap_at(405, 300)

    assert_instance_of Events::Penalized, event
    assert round.dots.to_a.last.fresh?, "the tap does not pass through"
  end

  def test_a_fresh_dot_out_from_under_the_popped_ones_can_be_popped
    round = round_with(dot(400, 300, popped: true), dot(480, 300))

    assert_instance_of Events::Popped, round.tap_at(520, 300)
    assert round.dots.to_a[1].popped?
  end

  def test_a_fresh_dot_on_top_of_a_popped_one_is_the_one_tapped
    round = round_with(dot(400, 300), dot(400, 300, popped: true))

    assert_instance_of Events::Popped, round.tap_at(400, 300)
  end

  def test_each_new_dot_spawns_under_all_the_others
    round = round_with(dot(400, 300))
    first = round.tap_at(400, 300).spawned
    clear_around!(round, first)
    second = round.tap_at(first.x, first.y).spawned

    assert_equal [first.id, second.id], round.dots.to_a.last(2).map(&:id)
    assert_equal 3, round.dots.map(&:id).uniq.size, "every dot has its own id"
  end

  def test_time_runs_down_and_dots_move_with_each_update
    round = round_with(dot(400, 300, velocity_x: 60))

    round.update(0.5)

    assert_in_delta 9.5, round.countdown.remaining
    assert_in_delta 430, round.dots.first.x
  end

  def test_the_round_ends_when_the_clock_reaches_zero_and_shows_zero
    round = round_with(dot(400, 300))

    round.update(10.4)

    assert round.over?
    assert_equal 0, round.countdown.whole_seconds
  end

  def test_a_penalty_can_end_the_round
    round = round_with(dot(400, 300, popped: true))
    round.update(8.5)

    round.tap_at(400, 300)

    assert round.over?
    assert_equal 0.0, round.countdown.remaining
  end

  def test_nothing_happens_once_the_round_is_over
    round = round_with(dot(400, 300, velocity_x: 60))
    round.update(11)
    resting = round.dots.first

    assert_nil round.tap_at(resting.x, resting.y)
    round.update(1)
    assert_equal resting, round.dots.first
    assert_equal 0, round.score
  end

  def test_resizing_keeps_every_dot_on_screen
    round = round_with(dot(780, 590))

    round.field = field(400, 300)

    assert_equal [350.0, 250.0], [round.dots.first.x, round.dots.first.y]
  end
end
