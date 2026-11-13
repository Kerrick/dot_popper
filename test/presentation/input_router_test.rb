# frozen_string_literal: true

require_relative "presentation_helper"

class InputRouterTest < Minitest::Test
  include PresentationTest

  def setup = @router = InputRouter.new

  def test_a_click_is_a_tap
    assert_equal Tap.new(x: 10.0, y: 20.0, kind: InputKind::MOUSE), @router.mouse_pressed(10, 20)
  end

  def test_a_finger_is_a_tap
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_pressed(:finger, 5, 6)
    assert @router.touch_pressed(Object.new, 5, 6)
  end

  def test_each_finger_is_its_own_tap
    taps = [[1, 10, 10], [2, 300, 200]].map { |id, x, y| @router.touch_pressed(id, x, y) }

    assert_equal [10.0, 300.0], taps.map(&:x)
  end

  def test_a_touch_without_a_position_is_ignored
    assert_nil @router.touch_pressed(1, nil, 6)
  end

  def test_moves_and_releases_are_sorted_as_presses_are
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.mouse_moved(3, 4)
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.mouse_released(3, 4)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_moved(1, 5, 6)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.touch_released(1, 5, 6)
  end

  def test_a_gamepad_press_is_a_click_at_the_cursor
    cursor = GamepadCursor.centered(layout.whole, style: Style::GAMEPAD, radius: R).at(120, 80)

    assert_equal Tap.new(x: 120.0, y: 80.0, kind: InputKind::GAMEPAD), @router.gamepad_pressed(cursor)
  end
end
