# frozen_string_literal: true

require_relative "../presentation/presentation_helper"
require "dot_popper/shell/lota_input"

# Lota's input callbacks as the game's own events (Shell::LotaInput): by
# the game's names, as they happened. Which of them are a player's own
# presses is the presentation's to decide (InputRouter#tap).
class LotaInputTest < Minitest::Test
  include PresentationTest

  def setup = @input = DotPopper::Shell::LotaInput.new

  def test_the_mouse_is_named_by_its_buttons_and_whether_sdl_made_it_up
    assert_equal MousePress.new(x: 10, y: 20, button: :left, made_up: false), @input.mouse_press(10, 20, 1, false)
    assert_equal %i[left right middle side4 side5], [1, 2, 3, 4, 5].map { @input.mouse_press(0, 0, it, false).button }
    assert_equal MouseRelease.new(x: 3, y: 4, button: :right, made_up: true), @input.mouse_release(3, 4, 2, true)
    assert_equal MouseMove.new(x: 3, y: 4, made_up: false), @input.mouse_move(3, 4, false)
  end

  def test_a_touch_says_whether_a_touchscreens_and_whether_made_up_from_the_mouse
    assert_equal TouchPress.new(id: 1, x: 5, y: 6, screen: true, made_up: false), @input.touch_press(1, 5, 6, :touchscreen, false)
    assert_equal TouchMove.new(id: 1, x: 5, y: 6, screen: true, made_up: false), @input.touch_move(1, 5, 6, "touchscreen", nil)
    assert_equal TouchRelease.new(id: 1, x: 0.5, y: 0.5, screen: false, made_up: false), @input.touch_release(1, 0.5, 0.5, :touchpad, false)
    assert @input.touch_press(1, 5, 6, :touchscreen, true).made_up
  end

  def test_a_gamepads_buttons_triggers_and_the_wheel
    assert_equal ButtonPress.new(button: :select), @input.button_press(:back)
    assert_equal ButtonRelease.new(button: nil), @input.button_release(:guide)
    assert_equal TriggerPull.new(trigger: :right, value: 0.75), @input.trigger_pull("triggerright", 0.75)
    assert_nil @input.trigger_pull(:leftx, 1.0), "a stick's axis is read each frame instead"
    assert_equal WheelTurn.new(notches: -2), @input.wheel_turn(-2)
  end

  def test_lotas_gamepad_buttons_are_named_as_the_game_names_them
    assert_equal({ a: :a, b: :b, x: :x, y: :y, start: :start, back: :select, leftshoulder: :lb, rightshoulder: :rb },
                 %i[a b x y start back leftshoulder rightshoulder].to_h { [it, @input.button(it)] })
    assert_equal :lb, @input.button("leftshoulder")
    %i[guide dpup dpleft leftstick rightstick misc1].each { assert_nil @input.button(it) }
  end

  def test_only_the_trigger_axes_are_triggers
    assert_equal [:left, :right, nil, nil], [:triggerleft, "triggerright", :leftx, :righty].map { @input.trigger(it) }
  end

  def test_lotas_keys_are_named_as_the_game_names_them_the_keypads_as_the_main_keys
    assert_equal %i[a z 0 9 7 minus minus enter enter page_up page_down escape],
                 %w[a z 0 9 kp7 minus kpminus return kpenter pageup pagedown escape].map { @input.key(it) }
    assert_equal :space, @input.key(:space)
    %w[lshift tab f1 kpplus].each { assert_nil @input.key(it) }
  end

  # A key press says which modifier keys are held, either side's, by
  # the game's names: Cmd on a Mac is LÖVE's gui key.
  def test_a_key_press_names_the_modifier_keys_held
    held = ->(*keys) { ->(*asked) { asked.intersect?(keys) } }

    assert_equal DotPopper::Presentation::KeyPress.new(key: :v, held: []), @input.key_press("v", held.call)
    assert_equal %i[ctrl], @input.key_press("v", held.call(:rctrl)).held
    assert_equal %i[alt command], @input.key_press("return", held.call(:lalt, :rgui)).held
    assert_nil @input.key_press("tab", held.call(:lctrl)).key
  end
end
