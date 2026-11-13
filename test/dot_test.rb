# frozen_string_literal: true

require "test_helper"

class DotTest < Minitest::Test
  include DotPopperTest

  def test_a_dot_moves_by_its_velocity_times_the_elapsed_time
    moving = dot(400, 300, velocity_x: 120, velocity_y: -60).move(0.5, field)

    assert_in_delta 460, moving.x
    assert_in_delta 270, moving.y
  end

  def test_the_distance_traveled_does_not_depend_on_the_frame_rate
    at_30 = dot(400, 300, velocity_x: 300, velocity_y: 240)
    at_144 = dot(400, 300, velocity_x: 300, velocity_y: 240)

    30.times { at_30 = at_30.move(1 / 30.0, field) }
    144.times { at_144 = at_144.move(1 / 144.0, field) }

    assert_in_delta at_30.x, at_144.x, 1e-6
    assert_in_delta at_30.y, at_144.y, 1e-6
    assert_equal at_30.velocity_x, at_144.velocity_x
  end

  def test_a_dot_bounces_off_the_right_edge_by_reversing_its_horizontal_velocity
    bouncing = dot(740, 300, velocity_x: 100, velocity_y: 10).move(0.3, field)

    assert_in_delta 750 - 20, bouncing.x # 30 px out, 10 to the edge, 20 back
    assert_equal(-100.0, bouncing.velocity_x)
    assert_equal 10.0, bouncing.velocity_y
  end

  def test_a_dot_bounces_off_the_top_and_left_edges
    bouncing = dot(60, 55, velocity_x: -100, velocity_y: -100).move(0.2, field)

    assert_in_delta 50 + 10, bouncing.x
    assert_in_delta 50 + 15, bouncing.y
    assert_equal 100.0, bouncing.velocity_x
    assert_equal 100.0, bouncing.velocity_y
  end

  def test_a_dot_bounces_off_the_bottom_edge
    bouncing = dot(400, 540, velocity_y: 100).move(0.2, field)

    assert_in_delta 550 - 10, bouncing.y
    assert_equal(-100.0, bouncing.velocity_y)
  end

  def test_a_dot_never_leaves_the_screen_even_in_a_very_long_frame
    random = Random.new(5)
    dots = Array.new(200) { DotPopper::Dot.spawn(field, random, id: 0) }

    dots.map { it.move(3.7, field) }.each do |d|
      assert_operator d.x, :>=, R
      assert_operator d.x, :<=, 800 - R
      assert_operator d.y, :>=, R
      assert_operator d.y, :<=, 600 - R
    end
  end

  def test_a_long_frame_that_crosses_both_edges_comes_out_going_the_same_way
    bouncing = dot(100, 300, velocity_x: 1400).move(1.0, field)

    assert_in_delta 100 + 1400 - (2 * 700), bouncing.x
    assert_equal 1400.0, bouncing.velocity_x
  end

  def test_speeds_change_only_by_bouncing
    steady = dot(400, 300, velocity_x: 60, velocity_y: 120)
    600.times { steady = steady.move(1 / 60.0, field) }

    assert_equal 60.0, steady.velocity_x.abs
    assert_equal 120.0, steady.velocity_y.abs
  end

  def test_a_dot_covers_points_within_its_radius_including_the_edge
    target = dot(400, 300)

    assert target.covers?(400, 300)
    assert target.covers?(450, 300)
    assert target.covers?(400 + 35, 300 + 35)
    refute target.covers?(400 + 36, 300 + 36)
    refute target.covers?(451, 300)
  end

  def test_dots_overlap_when_their_discs_touch
    target = dot(400, 300)

    assert target.overlaps?(dot(500, 300))
    refute target.overlaps?(dot(501, 300))
  end

  def test_popping_keeps_the_dot_moving
    original = dot(400, 300, velocity_x: 60)
    popped = original.pop

    assert popped.popped?
    assert original.bright?, "a dot is a value; popping gives a new one"
    assert_equal original.id, popped.id
    assert_in_delta 460, popped.move(1, field).x
  end

  def test_a_spawned_dot_has_its_own_speed_on_each_axis
    random = Random.new(11)
    dots = Array.new(300) { DotPopper::Dot.spawn(field, random, id: 0) }

    assert dots.any? { it.velocity_x.abs != it.velocity_y.abs }
    assert dots.all?(&:bright?)
  end

  def test_confining_puts_a_dot_back_on_a_smaller_field
    lost = dot(780, 590).confine(field(400, 300))

    assert_equal [350.0, 250.0], [lost.x, lost.y]
  end

  def test_refitting_keeps_a_dot_as_far_across_the_room_as_it_was
    moved = dot(50 + (0.7 * 700), 300, velocity_x: 40).refit(field(800, 600), field(400, 1000))

    assert_in_delta 50 + (0.7 * 300), moved.x, 1e-9
    assert_in_delta 50 + (0.5 * 900), moved.y, 1e-9
    assert_equal 40.0, moved.velocity_x
  end

  # A field narrower than a dot has no room across, so a dot there goes
  # to the new field's middle; one outside the old room is confined.
  def test_refitting_from_no_room_or_from_outside_still_lands_on_the_field
    assert_equal 200.0, dot(30, 300).refit(field(60, 600), field(400, 600)).x
    assert_equal [350.0, 250.0], dot(780, 590).refit(field(400, 300), field(400, 300)).then { [it.x, it.y] }
  end
end
