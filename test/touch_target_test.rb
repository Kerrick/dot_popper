# frozen_string_literal: true

require "test_helper"

class TouchTargetTest < Minitest::Test
  include DotPopperTest

  def test_a_target_lies_wholly_on_the_dot
    target = DotPopper::TouchTarget.on(R)

    assert_in_delta R - 22, target.reach
    target.offsets.each { |dx, dy| assert_operator Math.hypot(dx, dy), :<=, target.reach + 1e-9 }
  end

  # The sampling's resolution, as TouchTarget documents it.
  def test_every_point_a_target_could_center_on_is_within_three_and_a_half_units_of_a_sample
    random = Random.new(5)
    [30, 37.5, 50, 60.7, 98, 115.1, 120].each do |radius|
      target = DotPopper::TouchTarget.on(radius)
      500.times do
        angle = random.rand(2 * Math::PI)
        distance = Math.sqrt(random.rand) * target.reach
        x = distance * Math.cos(angle)
        y = distance * Math.sin(angle)
        nearest = target.offsets.map { |dx, dy| Math.hypot(dx - x, dy - y) }.min
        assert_operator nearest, :<=, 3.5, "radius #{radius}"
      end
    end
  end

  def test_a_dot_with_nothing_near_it_has_room
    assert DotPopper::TouchTarget.on(R).clear_on?(400.0, 300.0, [dot(600, 300)])
  end

  # With R 50, a target's center is within 28 of the dot's and at least
  # 72 from the one above, so a dot above 50 away leaves room and one 40
  # away does not.
  def test_a_dot_above_leaves_room_only_if_it_is_far_enough_off_center
    target = DotPopper::TouchTarget.on(R)

    assert target.clear_on?(400.0, 300.0, [dot(450, 300)])
    refute target.clear_on?(400.0, 300.0, [dot(440, 300)])
    refute target.clear_on?(400.0, 300.0, [dot(370, 300), dot(450, 300)]), "covered from both sides"
  end

  # 72 is a target's clearance from a dot above at R 50, and 28 its
  # reach, so a dot above covers every place for one within 44 of center.
  def test_a_dot_above_covers_every_place_for_a_target_only_when_it_is_close
    target = DotPopper::TouchTarget.on(R)

    assert target.covered_by?(400.0, 300.0, dot(443, 300))
    refute target.covered_by?(400.0, 300.0, dot(445, 300))
  end

  def test_a_dot_too_small_for_a_target_has_no_room_at_all
    target = DotPopper::TouchTarget.on(20)

    refute target.fits?
    assert_empty target.offsets
  end
end
