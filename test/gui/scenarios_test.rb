# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "fileutils"

# The game played end to end in real windows: each test starts the game
# as `lota run` does, with DOT_POPPER_SCENARIO naming a scripted session
# (test/gui/director.rb), and checks that it quit with status 0 after
# printing what it checked. Only rake test:gui runs these: each opens a
# window, and needs a display.
#
# Every run is silent (ALSOFT_DRIVERS=null), saves in a folder of its own
# that it removes after, opens at 1200 by 800, and plays from the same
# seed and date, so a run plays the same dots on any machine.
class GuiScenariosTest < Minitest::Test
  GAME = File.expand_path("../..", __dir__)

  def test_a_round_from_title_to_title
    play("round", "screens come in order", "hidden under it is outlined", "Game Over teaches the stacking rule",
         "a click on empty space at Game Over does nothing", "Continue goes back to the title", "rounds.csv logs the score")
  end

  def test_resizing_a_round_and_the_pile
    play("resizing", "a resize to 500x400", "F11 fullscreen", "fullscreen off",
         "the pile's dots are all inside the shrunk window")
  end

  def test_the_records_screen
    play("records", "a click on Back goes back", "Escape goes back", "a gamepad's B goes back",
         "a click elsewhere does nothing")
  end

  def test_the_credits_screen
    play("credits", "a click on Credits opens them", "the wheel scrolls down", "End goes to the end",
         "a finger's drag moves the page along", "Escape goes back to the Records screen",
         "a gamepad's B goes back to the Records screen", "Escape again goes back to the title")
  end

  def test_clearing_the_records_and_undoing_it
    play("clearing", "letting go too soon clears nothing", "Undo restores every file exactly",
         "the playtest log is untouched", "a press of Y undoes")
  end

  def test_choosing_the_dot_size_on_a_narrow_window
    play("dot_size", "the first round's dots are sized to the window", "the next round's dots are the standard size",
         window: "400x850")
  end

  def test_dragging_and_tilting_the_pile
    output = play("pile", "the dragged dot follows the mouse", "the thrown dot flies on up",
                  "the tilt rolls the pile to the left", DOT_POPPER_FAKE_TILT: "0.6,0")
    assert_includes output, "tilt from a fake reading"
  end

  def test_dragging_the_pile_with_a_gamepad
    output = play("pile_gamepad", "A held on a dot drags it up", "a quick press of A goes on",
                  DOT_POPPER_FAKE_GAMEPAD: "1", DOT_POPPER_FAKE_DRAG: "0.5,0.9,0.3,0.3")
    assert_includes output, "the fake drag takes a dot"
    assert_includes output, "the fake drag throws a dot"
  end

  def test_the_mouse_over_a_button_lights_it_and_shows_the_hand
    play("hover", "the mouse over Your records hovers it", "the pointer is the pointing hand",
         "moving away clears the hover and the hand", "a finger over it leaves no hover")
  end

  def test_the_words_follow_the_input
    play("words", "makes it Tap", "makes it Click", "makes it Press A")
  end

  def test_sharing_shows_the_result_and_copies_only_on_copy
    play("share", "Share my score is drawn", "opening the preview leaves the clipboard alone",
         "a click on Copy copies exactly the text shown", "Escape closes the preview", "Y again copies",
         "a gamepad's B closes the preview", "a tap beside the card closes", "Continue goes back to the title")
  end

  def test_sharing_on_an_upright_phone_sized_window
    play("share", "a tap on Copy copies", window: "400x850")
  end

  def test_a_round_without_shaders
    play("round", "screens come in order", DOT_POPPER_NO_SHADERS: "1")
  end

  private

  # Plays scenario +name+ and returns what it printed, after checking it
  # passed and printed each of +lines+.
  def play(name, *lines, window: "1200x800", **env)
    output, status = Open3.capture2e(environment(name, window, env), "bundle", "exec", "lota", "run", ".",
                                     chdir: GAME)
    clean_up(output)
    assert status.success?, "Scenario #{name} exited with #{status.exitstatus}:\n#{output}"
    assert_includes output, "gui: scenario #{name} passed", output
    lines.each { assert_includes output, it, "Scenario #{name} should print #{it.inspect}:\n#{output}" }
    output
  end

  def environment(name, window, env)
    { "DOT_POPPER_SCENARIO" => name, "DOT_POPPER_SAVE_AS" => "dot_popper_gui_#{name}_#{Process.pid}",
      "DOT_POPPER_WINDOW" => window, "DOT_POPPER_SEED" => "7", "DOT_POPPER_TODAY" => "2026-11-07",
      "ALSOFT_DRIVERS" => "null", **env.transform_keys(&:to_s) }
  end

  # Removes the run's save folder, which it names as it starts.
  def clean_up(output)
    folder = output[/^gui: save folder (.+)$/, 1]
    FileUtils.rm_rf(folder) if folder&.include?("dot_popper_gui_")
  end
end
