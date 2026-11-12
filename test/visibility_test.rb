# frozen_string_literal: true

require "test_helper"

class VisibilityTest < Minitest::Test
  include DotPopperTest

  def test_a_dot_with_nothing_above_it_is_fully_visible
    assert_equal 1.0, DotPopper::Visibility.of(dot(400, 300), [])
  end

  def test_a_dot_far_from_those_above_is_fully_visible
    assert_equal 1.0, DotPopper::Visibility.of(dot(400, 300), [dot(400 + (3 * R), 300)])
  end

  def test_a_dot_exactly_under_another_shows_nothing
    assert_equal 0.0, DotPopper::Visibility.of(dot(400, 300), [dot(400, 300)])
  end

  def test_a_dot_half_covered_shows_about_half
    # Two circles whose centers are one radius apart overlap in a lens of 39% of a disc.
    assert_in_delta 0.61, DotPopper::Visibility.of(dot(400, 300), [dot(400 + R, 300)]), 0.02
  end

  def test_several_dots_above_cover_what_each_covers
    left = dot(400 - R, 300)
    right = dot(400 + R, 300)

    assert_operator DotPopper::Visibility.of(dot(400, 300), [left, right]), :<,
                    DotPopper::Visibility.of(dot(400, 300), [left])
  end

  def test_the_share_does_not_depend_on_the_dots_size
    small = DotPopper::Dot.new(id: 1, x: 100, y: 100, velocity_x: 0, velocity_y: 0, radius: 30)
    cover = DotPopper::Dot.new(id: 2, x: 130, y: 100, velocity_x: 0, velocity_y: 0, radius: 30)

    assert_in_delta DotPopper::Visibility.of(dot(400, 300), [dot(400 + R, 300)]),
                    DotPopper::Visibility.of(small, [cover]), 0.03
  end

  def test_the_samples_lie_within_the_disc_and_are_frozen
    assert_equal DotPopper::Visibility::SAMPLES, DotPopper::Visibility::POINTS.size
    assert(DotPopper::Visibility::POINTS.all? { |x, y| Math.hypot(x, y) <= 1.0 })
    assert_predicate DotPopper::Visibility::POINTS, :frozen?
  end
end
