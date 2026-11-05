# frozen_string_literal: true

require_relative "presentation_helper"

class GamepadButtonsTest < Minitest::Test
  include PresentationTest

  def setup = @buttons = GamepadButtons.new

  def test_each_button_asks_for_its_intent
    assert_equal({ a: :press, start: :start, y: :share, x: :records, b: :leave, back: :mute, leftshoulder: :sizing,
                   rightshoulder: :sizing },
                 %i[a start y x b back leftshoulder rightshoulder].to_h { [it, @buttons.intent(it)] })
    assert_equal :press, @buttons.intent("a")
  end

  def test_other_buttons_ask_for_nothing
    %i[guide dpup dpleft leftstick].each { assert_nil @buttons.intent(it) }
  end

  def test_the_trigger_presses_once_per_pull
    look = Look::GAMEPAD
    readings = [0.2, 0.6, 0.9, 0.4, 0.6, 0.1, 0.55]
    trigger = Trigger.released
    presses = readings.map { (trigger = trigger.pull(it, look)).pressed }

    assert_equal [false, true, false, false, false, false, true], presses
  end
end
