# frozen_string_literal: true

require_relative "presentation_helper"

class PileTest < Minitest::Test
  include PresentationTest

  def test_gravity_scales_with_the_dot
    assert_in_delta 2 * Style::PILE.gravity_for(R), Style::PILE.gravity_for(2 * R)
  end

  def test_a_slow_frame_steps_the_world_only_so_far
    assert_in_delta Style::PILE.longest_step, Style::PILE.step(0.5)
    assert_in_delta 0.01, Style::PILE.step(0.01)
    assert_in_delta 0.0, Style::PILE.step(-1)
  end

  def test_a_dot_keeps_its_last_velocity
    assert_equal [120.0, -60.0], Style::PILE.launch(dot(0, 0, velocity_x: 120, velocity_y: -60))
  end

  def test_a_calm_pile_never_bounces_and_falls_gently
    calm = Style::CALM_PILE

    assert_in_delta 0.0, calm.restitution
    assert_operator calm.gravity, :<, Style::PILE.gravity
    assert_operator calm.fling, :<, Style::PILE.fling
  end

  def test_the_walls_are_the_floor_and_sides_with_an_open_top
    floor_and_sides = PileWalls.new(width: 800, height: 600).segments

    assert_includes floor_and_sides, [0.0, 600.0, 800.0, 600.0]
    assert(floor_and_sides.all? { |_x1, y1, _x2, y2| [y1, y2].min.negative? || y1 == y2 })
    refute(floor_and_sides.any? { |_x1, y1, _x2, y2| y1 == y2 && y1 <= 0 })
  end
end
