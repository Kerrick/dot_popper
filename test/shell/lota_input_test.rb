# frozen_string_literal: true

require_relative "../presentation/presentation_helper"
require "dot_popper/shell/lota_input"

# Lota's input callbacks as the game's taps (Shell::LotaInput): only a
# player's own finger or mouse is heard, so one finger is one tap.
class LotaInputTest < Minitest::Test
  include PresentationTest

  def setup = @input = DotPopper::Shell::LotaInput.new

  def test_a_click_is_a_tap
    assert_equal Tap.new(x: 10.0, y: 20.0, kind: InputKind::MOUSE), @input.mouse_pressed(10, 20, 1, false)
    assert_nil @input.mouse_pressed(10, 20, 4, false)
  end

  def test_the_mouse_press_sdl_makes_up_for_a_touch_is_ignored
    assert_nil @input.mouse_pressed(10, 20, 1, true)
    assert_nil @input.mouse_moved(3, 4, true)
    assert_nil @input.mouse_released(3, 4, 1, true)
  end

  def test_a_finger_on_a_touchscreen_is_a_tap
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @input.touch_pressed(:finger, 5, 6, :touchscreen, false)
    assert @input.touch_pressed(Object.new, 5, 6, "touchscreen", nil)
  end

  def test_a_trackpad_touch_is_not_a_tap
    assert_nil @input.touch_pressed(1, 0.5, 0.5, :touchpad, false)
    assert_nil @input.touch_released(1, 0.5, 0.5, :touchpad, false)
  end

  def test_a_touch_that_came_from_the_mouse_is_not_a_tap
    assert_nil @input.touch_pressed(1, 5, 6, :touchscreen, true)
  end

  def test_moves_and_releases_are_sorted_as_presses_are
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @input.mouse_moved(3, 4, false)
    assert_equal Tap.new(x: 3.0, y: 4.0, kind: InputKind::MOUSE), @input.mouse_released(3, 4, 1, false)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @input.touch_moved(1, 5, 6, :touchscreen, false)
    assert_equal Tap.new(x: 5.0, y: 6.0, kind: InputKind::TOUCH), @input.touch_released(1, 5, 6, :touchscreen, false)
  end
end
