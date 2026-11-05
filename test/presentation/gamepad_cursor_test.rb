# frozen_string_literal: true

require_relative "presentation_helper"

class GamepadCursorTest < Minitest::Test
  include PresentationTest

  LOOK = Look::GAMEPAD

  def setup = @cursor = GamepadCursor.centered(layout.whole, look: LOOK, radius: R)

  def test_it_starts_hidden_in_the_middle_of_the_window
    assert_equal [400.0, 300.0, false], [@cursor.x, @cursor.y, @cursor.visible]
  end

  def test_a_full_tilt_gathers_speed_over_the_ramp_and_shows_it
    moved = @cursor.update(0.1, Stick.new(x: 1, y: 0))

    assert_in_delta 400 + (@cursor.top_speed * 0.1 * (0.1 / LOOK.ramp)), moved.x
    assert_in_delta 300.0, moved.y
    assert moved.visible
    ramped = 3.times.reduce(@cursor) { |cursor, _| cursor.update(0.1, Stick.new(x: 1, y: 0)) }

    assert_in_delta 1.0, ramped.pace
    assert_in_delta ramped.x + (@cursor.top_speed * 0.1), ramped.update(0.1, Stick.new(x: 1, y: 0)).x
  end

  def test_at_full_tilt_it_crosses_any_large_window_corner_to_corner_in_about_a_second
    [[800, 600], [1920, 1080], [3840, 2160]].each do |width, height|
      area = layout(width, height).whole
      cursor = GamepadCursor.centered(area, look: LOOK, radius: R).at(0, 0)
      across = Math.hypot(width, height)
      push = Stick.new(x: width / across, y: height / across)
      frames = 0
      frames += 1 while (cursor = cursor.update(1 / 60.0, push)).x < width - 0.5 && frames < 600

      assert_in_delta LOOK.crossing, frames / 60.0, 0.05, "#{width}x#{height}"
    end
  end

  def test_a_small_window_keeps_the_looks_speed_in_radii
    small = GamepadCursor.centered(layout(400, 320).whole, look: LOOK, radius: R)

    assert_in_delta LOOK.speed * R, small.top_speed
    assert_operator @cursor.top_speed, :>, LOOK.speed * R
  end

  def test_letting_go_stops_it_and_it_gathers_speed_afresh
    moving = 4.times.reduce(@cursor) { |cursor, _| cursor.update(0.1, Stick.new(x: 1, y: 0)) }
    stopped = moving.update(0.1, Stick.rest)

    assert_equal [moving.x, 0.0], [stopped.x, stopped.pace]
    assert_same stopped, stopped.update(0.1, Stick.rest)
  end

  def test_a_push_inside_the_dead_zone_is_a_stick_at_rest
    resting = @cursor.update(1.0, Stick.new(x: LOOK.dead_zone * 0.9, y: -0.05))

    assert_same @cursor, resting
    refute resting.visible
  end

  def test_a_small_tilt_aims_finely_along_the_curve_at_once
    half = LOOK.dead_zone + ((1 - LOOK.dead_zone) / 2)
    moved = @cursor.update(0.1, Stick.new(x: 0, y: -half))

    assert_in_delta 300 - (@cursor.top_speed * 0.1 * (0.5**LOOK.curve)), moved.y
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
