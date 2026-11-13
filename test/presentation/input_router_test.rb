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

  # Only a player's own finger or mouse is heard, so one finger is one tap.
  def test_a_click_with_any_main_button_is_a_tap
    %i[left right middle].each { assert_equal Tap.new(x: 10.0, y: 20.0, kind: InputKind::MOUSE), @router.tap(MousePress.new(x: 10, y: 20, button: it, made_up: false)) }
    assert_nil @router.tap(MousePress.new(x: 10, y: 20, button: :side4, made_up: false)), "a side button"
    assert_nil @router.tap(MouseRelease.new(x: 3, y: 4, button: :side5, made_up: false))
  end

  def test_the_mouse_press_sdl_makes_up_for_a_touch_is_ignored
    assert_nil @router.tap(MousePress.new(x: 10, y: 20, button: :left, made_up: true))
    assert_nil @router.tap(MouseMove.new(x: 3, y: 4, made_up: true))
    assert_nil @router.tap(MouseRelease.new(x: 3, y: 4, button: :left, made_up: true))
  end

  def test_a_finger_on_a_touchscreen_is_a_tap_and_a_trackpads_or_the_mouses_is_not
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.tap(TouchPress.new(id: 1, x: 5, y: 6, screen: true, made_up: false))
    assert_nil @router.tap(TouchPress.new(id: 1, x: 0.5, y: 0.5, screen: false, made_up: false))
    assert_nil @router.tap(TouchRelease.new(id: 1, x: 0.5, y: 0.5, screen: false, made_up: false))
    assert_nil @router.tap(TouchPress.new(id: 1, x: 5, y: 6, screen: true, made_up: true))
  end

  def test_events_sorted_as_presses_are
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.tap(MouseMove.new(x: 3, y: 4, made_up: false))
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @router.tap(MouseRelease.new(x: 3, y: 4, button: :left, made_up: false))
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @router.tap(TouchMove.new(id: 1, x: 5, y: 6, screen: true, made_up: false))
    assert_nil @router.tap(WheelTurn.new(notches: 1))
  end

  def test_a_gamepad_press_is_a_click_at_the_cursor
    cursor = GamepadCursor.centered(layout.whole, style: Style::GAMEPAD, radius: R).at(120, 80)

    assert_equal Tap.new(x: 120.0, y: 80.0, kind: InputKind::GAMEPAD), @router.gamepad_pressed(cursor)
  end
end
