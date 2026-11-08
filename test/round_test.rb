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

  # Turning a tall phone and back leaves the dots where they were, not
  # bunched into the narrow side (the iPhone playtest).
  def test_turning_keeps_each_dot_where_it_was_in_proportion
    portrait = field(375, 812)
    landscape = field(812, 375)
    near_corner = dot(50 + (0.7 * 275), 50 + (0.2 * 712), velocity_x: 60, velocity_y: -90)
    round = DotPopper::Round.new(portrait, random: Random.new(1), dots: DotPopper::Stack.new([near_corner]))

    round.field = landscape
    turned = round.dots.first

    assert_in_delta 50 + (0.7 * 712), turned.x, 1e-9, "70% across stays 70% across"
    assert_in_delta 50 + (0.2 * 275), turned.y, 1e-9
    assert_equal [60.0, -90.0], [turned.velocity_x, turned.velocity_y], "velocities stay in radii per second"

    round.field = portrait
    back = round.dots.first

    assert_in_delta near_corner.x, back.x, 1e-9, "turning back puts it back"
    assert_in_delta near_corner.y, back.y, 1e-9
  end
  # The tutorial's state, as Round.resume carries it into the round: two
  # popped dots on top, and the fresh one born under both.
  # Its wrong taps cost what they do in play, so it may leave less: as
  # little as +score+ 0 and +seconds+ 1.
  def resumed(score: 2, seconds: 12.0)
    first = dot(300, 300, popped: true, id: 0)
    second = dot(340, 300, popped: true, id: 1)
    fresh = dot(500, 300, velocity_x: 60, id: 2)
    DotPopper::Round.resume(field, dots: DotPopper::Stack.new(dots: [first, second, fresh]), score:, seconds:,
                                   random: Random.new(1))
  end

  def test_a_resumed_round_starts_from_the_dots_score_and_clock_it_is_given
    round = resumed

    assert_equal [0, 1, 2], round.dots.map(&:id)
    assert_equal [true, true, false], round.dots.map(&:popped?)
    assert_equal 2, round.score
    assert_in_delta 12.0, round.countdown.remaining
    assert_in_delta 0.0, round.elapsed
    refute round.over?
  end

  def test_a_resumed_rounds_clock_runs_from_its_first_update_and_its_dots_go_on_moving
    round = resumed
    round.update(0.5)

    assert_in_delta 11.5, round.countdown.remaining
    assert_in_delta 0.5, round.elapsed
    assert_in_delta 530.0, round.dots.to_a.last.x
  end

  def test_a_resumed_round_plays_by_the_usual_rules
    round = resumed

    missed = round.tap_at(300, 300)
    assert_instance_of Events::Penalized, missed, "a tap reaches only the topmost dot"
    assert_equal [0, 10.0], [round.score, round.countdown.remaining]

    popped = round.tap_at(500, 300)
    assert_instance_of Events::Popped, popped
    assert_equal [1, 11.0], [round.score, round.countdown.remaining]
    assert_equal 3, popped.spawned.id, "its new dot takes the next id"
    assert_equal [0, 1, 2, 3], round.dots.map(&:id), "and goes in under every dot there"
    assert round.dots.to_a.last.fresh?
  end

  def test_a_resumed_round_ends_when_its_clock_runs_out
    round = resumed
    round.update(12.5)

    assert round.over?
    assert_in_delta 12.0, round.elapsed
  end

  def test_a_resumed_round_at_no_points_keeps_the_score_floor
    round = resumed(score: 0, seconds: 7.0)

    refute round.over?
    penalty = round.tap_at(300, 300)
    assert_equal 0, penalty.points, "there was nothing to lose"
    assert_equal [0, 5.0], [round.score, round.countdown.remaining]
    round.tap_at(500, 300)
    assert_equal [1, 6.0], [round.score, round.countdown.remaining]
  end

  def test_a_resumed_round_with_little_time_left_runs_it_out_and_no_further
    round = resumed(score: 1, seconds: 1.0)

    refute round.over?, "a second on the clock is a second to play"
    round.update(0.6)
    refute round.over?
    round.update(0.6)
    assert round.over?
    assert_in_delta 1.0, round.elapsed
    assert_nil round.tap_at(500, 300), "and then no tap counts"
  end

  def test_a_wrong_tap_with_less_than_two_seconds_left_ends_a_resumed_round
    round = resumed(score: 1, seconds: 1.0)
    round.tap_at(300, 300)

    assert round.over?
    assert_equal 0, round.score
  end
end
