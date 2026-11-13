# frozen_string_literal: true

# Each test here starts the real game in a window, on whatever display it
# finds, so anything that loads this file, a runner that requires every
# test file included, would open windows on the screen of whoever runs
# it. It refuses unless DOT_POPPER_OPEN_WINDOWS is 1, which rake test:gui
# sets, and which a person sets to ask for the windows plainly.
unless ENV["DOT_POPPER_OPEN_WINDOWS"] == "1"
  abort <<~REFUSAL
    #{__FILE__} starts the game in real windows, one a test, so it runs only when asked:
      bundle exec rake test:gui
    under a virtual display where no one is using the screen, as CI runs it:
      xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" bash script/with-openbox.sh bundle exec rake test:gui
    To open the windows anyway, set DOT_POPPER_OPEN_WINDOWS=1.
  REFUSAL
end

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

  def test_a_game_from_home_to_home
    play("game", "screens come in order", "hidden under it is outlined", "Game Over teaches the stacking rule",
         "a click on empty space at Game Over does nothing", "Play again starts the next game at once",
         "Home goes back Home", "games.csv logs the score")
  end

  def test_resizing_a_game_and_the_pile
    play("resizing", "a resize to 500x400", "F11 fullscreen", "fullscreen off",
         "the pile's dots are all inside the shrunk window")
  end

  def test_full_screen_and_quit_on_home_by_the_mouse_alone
    play("window_buttons", "Full screen is drawn as Borderless", "a click on Full screen fills the screen",
         "the button now says Window", "a click on Window puts the window back",
         "a click on Quit asks Lota to quit at once")
  end

  def test_full_screen_and_quit_as_icons_on_the_smallest_window
    play("window_buttons", "Quit is drawn", "a click on Full screen fills the screen",
         "a click on Quit asks Lota to quit at once", window: "400x320")
  end

  def test_the_stats_screen
    play("stats", "a click on Back goes back", "Escape goes back", "a gamepad's B goes back",
         "a click elsewhere does nothing")
  end

  def test_the_credits_screen
    play("credits", "a click on Credits and licenses opens them", "the wheel scrolls down", "End goes to the end",
         "a finger's drag moves the page along", "Escape goes back to Settings",
         "a gamepad's B goes back to Settings", "Escape again goes back Home")
  end

  def test_using_a_theme_with_pro
    play("themes", "Home offers Themes",
         "a click on the ordinary theme's card uses it at once", "Escape leaves Themes for Home",
         DOT_POPPER_PRO: "1", DOT_POPPER_THEME_UNLOCKS: "ghost")
  end

  def test_clearing_the_stats_and_undoing_it
    play("clearing", "letting go too soon clears nothing", "Undo restores every file exactly",
         "the games log is untouched", "a press of Y undoes")
  end

  def test_choosing_the_dot_size_on_a_narrow_window
    play("dot_size", "the first game's dots are standard for the window", "the next game's dots are the bigger size",
         window: "400x850")
  end

  def test_dragging_and_tilting_the_pile
    output = play("pile", "the dragged dot follows the mouse", "the thrown dot flies on up",
                  "the tilt rolls the pile to the left", DOT_POPPER_FAKE_TILT: "0.6,0")
    assert_includes output, "tilt from a fake reading"
  end

  def test_dragging_the_pile_with_a_gamepad
    output = play("pile_gamepad", "A held on a dot drags it up", "a quick press of A plays again",
                  DOT_POPPER_FAKE_GAMEPAD: "1", DOT_POPPER_FAKE_DRAG: "0.5,0.9,0.3,0.3")
    assert_includes output, "the fake drag takes a dot"
    assert_includes output, "the fake drag throws a dot"
  end

  def test_the_mouse_over_a_button_lights_it_and_shows_the_hand
    play("hover", "the mouse over Your stats hovers it", "the pointer is the pointing hand",
         "moving away clears the hover and the hand", "a finger over it leaves no hover")
  end

  def test_the_words_follow_the_input
    play("words", "makes it touch", "makes it the mouse", "makes it Press A", "Escape on Home asks, naming Escape")
  end

  def test_sharing_shows_the_result_and_copies_only_on_copy
    play("share", "Share my score is drawn", "opening the preview leaves the clipboard alone",
         "a click on Copy copies exactly the text shown", "Escape closes the preview", "Y again copies",
         "a gamepad's B closes the preview", "a tap beside the card closes", "Home goes back Home")
  end

  def test_sharing_on_an_upright_phone_sized_window
    play("share", "a tap on Copy copies", window: "400x850")
  end

  def test_a_free_player_buys_the_pro_version_on_a_test_builds_store
    play("purchase", "the games have run out", "Play leads to the offer", "the store gave its price", "Buy reaches the checkout, which sends a license key",
         "the Stats screen no longer offers the purchase", "Themes opens", "scenario purchase passed",
         DOT_POPPER_FREE_GAMES: "1", DOT_POPPER_THEME_UNLOCKS: "ghost")
  end

  def test_the_tutorial_played_through_with_a_mouse
    play("tutorial", "the first Play opens the tutorial", "a tap on the popped dot does nothing",
         "the game hears nothing of it", "a tap on the clear bright dot pops it", "the same game plays on",
         "the game goes on with the tutorial's dots", "and its 10 seconds",
         "no one heard of the game until play began", "tutorial.txt remembers", DOT_POPPER_TUTORIAL: "1")
  end

  def test_the_tutorial_by_touch_on_an_upright_phone_sized_window
    play("tutorial", "the point lands in the score", "the clock is lit", window: "400x850", DOT_POPPER_TUTORIAL: "1",
                                                                         DOT_POPPER_GUI_INPUT: "touch")
  end

  def test_the_tutorial_skipped_by_escape_and_by_a_tap
    play("tutorial_skip", "Escape skips it", "the skip button is drawn", "a tap on the skip button skips it",
         "the same game", "with the pop the player made", "which the HUD shows", DOT_POPPER_TUTORIAL: "1")
  end

  def test_the_tutorial_skipped_by_a_gamepads_b
    play("tutorial", "a gamepad's B skips it", DOT_POPPER_TUTORIAL: "1", DOT_POPPER_GUI_INPUT: "gamepad",
                                               DOT_POPPER_FAKE_GAMEPAD: "1")
  end

  def test_how_to_play_on_home_by_mouse_and_by_h
    play("how_to_play", "a first Home offers no How to play", "How to play is drawn",
         "How to play opens the tutorial at once", "Escape skips it",
         "H opens it again from Home")
  end

  def test_how_to_play_by_touch_on_an_upright_phone_sized_window
    play("how_to_play", "How to play is drawn", "How to play opens the tutorial at once", "H opens it again",
         window: "400x850", DOT_POPPER_GUI_INPUT: "touch")
  end

  def test_how_to_play_by_a_gamepads_y
    play("how_to_play", "How to play opens the tutorial at once", "a gamepad's B skips it",
         DOT_POPPER_GUI_INPUT: "gamepad", DOT_POPPER_FAKE_GAMEPAD: "1")
  end

  def test_popped_dots_are_alike_their_own_and_far_from_the_bright_one
    play("popped_dots", "popped dots differ in no color, lightness or size",
         "each dot is the same dot before and after its pop",
         "no popped dot comes near the bright one", "no dot moves with the time on the wall", DOT_POPPER_PRO: "1")
  end

  def test_a_game_without_shaders
    play("game", "screens come in order", DOT_POPPER_NO_SHADERS: "1")
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
      "ALSOFT_DRIVERS" => "null", "DOT_POPPER_SERVER" => "", **env.transform_keys(&:to_s) }
  end

  # Removes the run's save folder, which it names as it starts.
  def clean_up(output)
    folder = output[/^gui: save folder (.+)$/, 1]
    FileUtils.rm_rf(folder) if folder&.include?("dot_popper_gui_")
  end
end
