# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require "dot_popper/shell/gamepads"

# Gamepads holds the controllers Lota's callbacks hand over, and never
# asks Lota for the list itself, so it is tested with stand-ins.
class GamepadsTest < Minitest::Test
  Stick = DotPopper::Presentation::Stick

  class Pad < Data.define(:gamepad, :x)
    def gamepad? = gamepad
    def gamepad_axis(axis) = axis == :leftx ? x : 0.0
    def gamepad_down?(_button) = false
  end

  def test_with_no_controller_the_stick_is_at_rest
    assert_equal Stick.rest, DotPopper::Shell::Gamepads.new.stick
  end

  def test_an_added_gamepad_pushes_until_it_is_removed
    pads = DotPopper::Shell::Gamepads.new
    pad = Pad.new(gamepad: true, x: 0.5)

    pads.added(pad)
    pads.added(pad)
    assert_in_delta 0.5, pads.stick.x

    pads.removed(pad)
    assert_equal Stick.rest, pads.stick
  end

  def test_a_joystick_that_is_not_a_gamepad_is_ignored
    pads = DotPopper::Shell::Gamepads.new
    pads.added(Pad.new(gamepad: false, x: 1.0)) # an iPad's accelerometer, say

    assert_equal Stick.rest, pads.stick
  end

  def test_a_phone_or_tablet_takes_no_controllers
    pads = DotPopper::Shell::Gamepads.new(enabled: false)
    pads.added(Pad.new(gamepad: true, x: 1.0))

    assert_equal Stick.rest, pads.stick
  end
end
