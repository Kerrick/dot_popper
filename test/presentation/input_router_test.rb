# frozen_string_literal: true

require_relative "presentation_helper"

class InputRouterTest < Minitest::Test
  include PresentationTest

  def setup = @router = InputRouter.new

  def test_a_click_with_any_main_button_is_a_tap
    [1, 2, 3].each { assert_equal Tap.new(x: 10.0, y: 20.0, kind: InputKind::MOUSE), @router.mouse_pressed(10, 20, it, false) }
    assert_nil @router.mouse_pressed(10, 20, 4, false)
  end

  def test_the_mouse_press_sdl_makes_up_for_a_touch_is_ignored
    assert_nil @router.mouse_pressed(10, 20, 1, true)
  end

  def test_a_finger_on_a_touchscreen_is_a_tap
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_pressed(:finger, 5, 6, :touchscreen, false)
    assert @router.touch_pressed(Object.new, 5, 6, "touchscreen", nil)
  end

  def test_a_trackpad_touch_is_not_a_tap
    assert_nil @router.touch_pressed(1, 0.5, 0.5, :touchpad, false)
  end

  def test_a_touch_that_came_from_the_mouse_is_not_a_tap
    assert_nil @router.touch_pressed(1, 5, 6, :touchscreen, true)
  end

  def test_each_finger_is_its_own_tap
    taps = [[1, 10, 10], [2, 300, 200]].map { |id, x, y| @router.touch_pressed(id, x, y, :touchscreen, false) }

    assert_equal [10.0, 300.0], taps.map(&:x)
  end

  def test_a_touch_without_a_position_is_ignored
    assert_nil @router.touch_pressed(1, nil, 6, :touchscreen, false)
  end

  def test_moves_and_releases_are_sorted_as_presses_are
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.mouse_moved(3, 4, false)
    assert_nil @router.mouse_moved(3, 4, true)
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.mouse_released(3, 4, 1, false)
    assert_nil @router.mouse_released(3, 4, 1, true)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_moved(1, 5, 6, :touchscreen, false)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_released(1, 5, 6, :touchscreen, false)
    assert_nil @router.touch_released(1, 0.5, 0.5, :touchpad, false)
  end

  def test_a_gamepad_press_is_a_click_at_the_cursor
    cursor = GamepadCursor.centered(layout.whole, look: Look::GAMEPAD, radius: R).at(120, 80)

    assert_equal Tap.new(x: 120.0, y: 80.0, kind: InputKind::GAMEPAD), @router.gamepad_pressed(cursor)
  end
end
