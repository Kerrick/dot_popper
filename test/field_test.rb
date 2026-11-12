# frozen_string_literal: true

require "test_helper"

class FieldTest < Minitest::Test
  include DotPopperTest

  def test_a_new_dot_starts_at_least_one_radius_from_every_edge
    random = Random.new(42)
    centers = Array.new(5_000) { field.random_center(random) }

    xs, ys = centers.transpose
    assert_operator xs.min, :>=, R
    assert_operator xs.max, :<=, 800 - R
    assert_operator ys.min, :>=, R
    assert_operator ys.max, :<=, 600 - R
  end

  def test_new_dots_spread_across_the_whole_allowed_area
    random = Random.new(7)
    xs, ys = Array.new(5_000) { field.random_center(random) }.transpose

    assert_operator xs.min, :<, R + 10
    assert_operator xs.max, :>, 800 - R - 10
    assert_operator ys.min, :<, R + 10
    assert_operator ys.max, :>, 600 - R - 10
    assert_in_delta 400, xs.sum / xs.size, 10
  end

  def test_its_measurements_are_floats_whatever_it_is_given
    measurements = DotPopper::Field.new(800, 600, 50).to_h.values

    assert_equal [800.0, 600.0, 50.0], measurements
    assert measurements.all?(Float)
  end

  def test_a_field_narrower_than_a_dot_centers_it
    narrow = DotPopper::Field.new(60, 600, R)

    assert_equal 30.0, narrow.random_center(Random.new(1)).first
  end

  def test_each_axis_speed_is_one_of_the_five_in_radii_per_second_with_either_sign
    random = Random.new(3)
    speeds = Array.new(2_000) { field.random_speed(random) }

    expected = DotPopper::Rules::SPEEDS.flat_map { [it * R, -it * R] }
    assert_equal expected.sort, speeds.uniq.sort
  end

  def test_the_speeds_are_the_originals_one_to_five_pixels_a_frame
    assert_equal [1.2, 2.4, 3.6, 4.8, 6.0], DotPopper::Rules::SPEEDS
    assert_equal 60.0, 1.2 * R # 1 px a frame at 60 frames a second
  end
end
