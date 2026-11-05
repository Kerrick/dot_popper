# frozen_string_literal: true

require_relative "presentation_helper"

class DotAnimationsTest < Minitest::Test
  include PresentationTest

  def setup = @animations = DotAnimations.new(Look::MOTION)

  def test_a_dot_at_rest_is_drawn_at_its_size
    pose = @animations.pose(dot(0, 0, popped: true), 3.0)

    assert_equal Pose::STILL, pose
  end

  def test_a_fresh_dot_breathes_only_a_little
    scales = (0..40).map { @animations.pose(dot(0, 0), it * 0.05).scale_x }

    assert_operator scales.max - scales.min, :>, 0.01
    scales.each { assert_in_delta 1.0, it, Look::MOTION.breathe.amplitude + 1e-9 }
  end

  def test_a_new_dot_grows_from_a_seed_past_its_size_and_settles
    @animations.spawn(1, 0.0)
    fresh = dot(0, 0, id: 1)
    sizes = (0..50).map { @animations.pose(fresh, it * 0.01).scale_x }

    assert_operator sizes.first, :<, 0.3
    assert_operator sizes.max, :>, 1.03
    assert_in_delta 1.0, @animations.pose(fresh, 2.0).scale_x, Look::MOTION.breathe.amplitude + 1e-9
  end

  def test_a_popped_dot_squashes_keeping_its_area_and_springs_back
    @animations.pop(2, 1.0)
    popped = dot(0, 0, id: 2, popped: true)
    squashed = @animations.pose(popped, 1.0)

    assert_operator squashed.scale_x, :>, 1.2
    assert_in_delta 1.0, squashed.scale_x * squashed.scale_y, 1e-9
    assert_in_delta 1.0, @animations.pose(popped, 3.0).scale_x, 1e-3
  end

  def test_a_popped_dot_looks_popped_almost_at_once
    @animations.pop(2, 1.0)
    popped = dot(0, 0, id: 2, popped: true)

    assert_in_delta 1.0, @animations.pose(popped, 1.0).freshness
    assert_in_delta 0.0, @animations.pose(popped, 1.2).freshness
  end

  def test_a_wrong_tap_shudders_the_dot_then_stops
    @animations.wobble(3, 0.0)
    popped = dot(0, 0, id: 3, popped: true)
    shaking = (1..30).map { @animations.pose(popped, it * 0.01) }

    assert(shaking.any? { (it.scale_x - 1).abs > 0.05 })
    assert_operator shaking.first.alarm, :>, 0.9
    assert_equal Pose::STILL.scale_x, @animations.pose(popped, 1.0).scale_x
    assert_in_delta 0.0, @animations.pose(popped, 1.0).alarm
  end

  def test_dots_are_followed_by_id_not_by_value
    @animations.pop(4, 0.0)

    assert_equal @animations.pose(dot(0, 0, id: 4, popped: true), 0.0),
                 @animations.pose(dot(500, 300, id: 4, popped: true), 0.0)
  end

  def test_clearing_forgets_every_dot
    @animations.spawn(1, 0)
    @animations.clear

    assert_equal 0, @animations.size
  end
end
