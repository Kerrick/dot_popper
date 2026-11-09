# frozen_string_literal: true

require_relative "presentation_helper"

class GamepadButtonsTest < Minitest::Test
  include PresentationTest

  def setup = @buttons = GamepadButtons.new

  def test_each_button_asks_for_its_intent
    assert_equal({ a: :press, start: :start, b: :leave, back: :select, x: :x, y: :y, leftshoulder: :lb, rightshoulder: :rb },
                 %i[a start b back x y leftshoulder rightshoulder].to_h { [it, @buttons.intent(it)] })
  end

  # Settings opens from Home on View or Select, as a console game's
  # options do; there the same button turns Sound on or off.
  def test_select_opens_settings_on_home_and_turns_sound_off_and_on_there
    sounds = FakeSounds.new
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    show = Show.new(cabinet:, layout: layout(1200, 800), sounds:, radius: R)
    show.input = InputKind::GAMEPAD

    show.pad(@buttons.intent(:back))
    assert show.settings?
    assert_equal "Settings (Select)", show.words.settings
    show.pad(@buttons.intent(:back))
    assert sounds.muted?
    show.pad(@buttons.intent(:back))
    refute sounds.muted?
  end

  # Start plays on Home as A does, and B there asks before it quits.
  def test_start_plays_and_b_twice_quits_on_home
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    show = Show.new(cabinet:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R)
    assert_equal :asked, show.ask_to_quit
    assert_equal :quit, show.ask_to_quit

    show.start
    assert show.playing?
  end

  def test_other_buttons_ask_for_nothing
    %i[guide dpup dpleft leftstick rightstick].each { assert_nil @buttons.intent(it) }
  end

  def test_the_trigger_presses_once_per_pull
    style = Style::GAMEPAD
    readings = [0.2, 0.6, 0.9, 0.4, 0.6, 0.1, 0.55]
    trigger = Trigger.released
    presses = readings.map { (trigger = trigger.pull(it, style)).pressed }

    assert_equal [false, true, false, false, false, false, true], presses
  end
end
