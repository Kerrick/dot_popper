# frozen_string_literal: true

require_relative "presentation_helper"

class GamepadCursorTest < Minitest::Test
  include PresentationTest

  LOOK = Look::GAMEPAD

  def setup = @cursor = GamepadCursor.centered(layout.whole, look: LOOK, radius: R)

  def test_it_starts_hidden_in_the_middle_of_the_window
    assert_equal [400.0, 300.0, false], [@cursor.x, @cursor.y, @cursor.visible]
  end

  def test_a_full_tilt_moves_it_at_the_looks_speed_in_radii_and_shows_it
    moved = @cursor.update(0.1, Stick.new(x: 1, y: 0))

    assert_in_delta 400 + (LOOK.speed * R * 0.1), moved.x
    assert_in_delta 300.0, moved.y
    assert moved.visible
  end

  def test_a_push_inside_the_dead_zone_is_a_stick_at_rest
    resting = @cursor.update(1.0, Stick.new(x: LOOK.dead_zone * 0.9, y: -0.05))

    assert_same @cursor, resting
    refute resting.visible
  end

  def test_a_small_tilt_aims_finely_along_the_curve
    half = LOOK.dead_zone + ((1 - LOOK.dead_zone) / 2)
    moved = @cursor.update(1.0, Stick.new(x: 0, y: -half))

    assert_in_delta 300 - (LOOK.speed * R * (0.5**LOOK.curve)), moved.y
    assert_operator 0.5**LOOK.curve, :<, 0.5
  end

  def test_the_push_rises_from_nothing_at_the_dead_zones_edge
    edge = Stick.new(x: LOOK.dead_zone + 0.001, y: 0).shaped(LOOK.dead_zone, LOOK.curve)

    assert_operator edge.x, :<, 0.001
  end

  def test_a_diagonal_moves_no_faster_than_a_straight_push
    diagonal = Stick.dpad(left: false, right: true, up: false, down: true).shaped(LOOK.dead_zone, LOOK.curve)

    assert_in_delta 1.0, Math.hypot(diagonal.x, diagonal.y)
    assert_in_delta diagonal.x, diagonal.y
  end

  def test_the_dpad_pushes_fully_and_opposite_arrows_cancel
    assert_equal Stick.new(x: -1, y: -1), Stick.dpad(left: true, right: false, up: true, down: false)
    assert_predicate Stick.dpad(left: true, right: true, up: false, down: false), :rest?
  end

  def test_a_stick_and_a_dpad_together_push_at_most_a_full_tilt
    assert_equal Stick.new(x: 1, y: 0), Stick.new(x: 0.8, y: 0) + Stick.dpad(left: false, right: true, up: false, down: false)
  end

  def test_it_stays_inside_the_window
    pushed = 10.times.reduce(@cursor) { |cursor, _| cursor.update(0.1, Stick.new(x: -1, y: 1)) }

    assert_equal [0.0, 600.0], [pushed.x, pushed.y]
  end

  def test_the_mouse_hides_it_where_the_mouse_is
    hidden = @cursor.show.hide(120, 80)

    assert_equal [120.0, 80.0, false], [hidden.x, hidden.y, hidden.visible]
    assert_equal [0.0, 600.0], @cursor.hide(-5, 900).then { [it.x, it.y] }
  end

  def test_a_smaller_window_keeps_it_inside
    refit = @cursor.at(790, 590).refit(layout(400, 320).whole)

    assert_equal [400.0, 320.0], [refit.x, refit.y]
  end
end
