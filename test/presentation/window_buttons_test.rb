# frozen_string_literal: true

require_relative "presentation_helper"

# A desktop's title offers "Full screen" and Quit, so a player with only
# a mouse can fill the screen, and leave a game that fills it, where the
# window's own buttons are gone. A click on either does its job at once;
# a phone or tablet offers neither.
class WindowButtonsTest < Minitest::Test
  include PresentationTest

  def setup
    @window = FakeWindow.new
    @game = DotPopper::Game.new(field(1200, 800), random: Random.new(2))
    @show = Show.new(game: @game, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, window: @window)
  end

  def test_a_click_on_full_screen_switches_the_window_and_a_second_switches_it_back
    click(:fullscreen)
    assert @window.fullscreen?

    click(:fullscreen)
    refute @window.fullscreen?
    assert @show.title?, "the title stays"
  end

  # A labelled button pressed on purpose is no stray press, so it asks
  # nothing more, as a gamepad's B does; aimed at with a gamepad's
  # cursor and pressed with A, it is as deliberate.
  def test_a_click_on_quit_quits_at_once_and_so_does_a_gamepads_press_on_it
    click(:quit)
    assert_equal 1, @window.quits

    reach = @show.reach_of(:quit)
    @show.tap(reach.center_x, reach.center_y, by: :gamepad)
    assert_equal 2, @window.quits
    assert_equal 0.0, @show.quit_prompt, "nothing asks to press again"
  end

  def test_the_mouse_over_either_lights_it
    %i[fullscreen quit].each do |name|
      reach = @show.reach_of(name)
      @show.pointer_at(reach.center_x, reach.center_y)

      assert_equal name, @show.hovered
    end
  end

  # Only the title offers them: Records, Game Over and the rest each go
  # back to it, by a click on Back or Continue, so a player in
  # fullscreen with only a mouse is never stuck there.
  def test_only_the_title_offers_them
    @show.primary
    refute_window_buttons "a round"
    @game.update(30)
    @show.update(1.0)
    refute_window_buttons "Game Over"
    assert @show.continue_reach, "Continue goes back to the title"
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.primary
    @show.open_records
    refute_window_buttons "the Records screen"
    assert @show.back_reach, "Back goes back to the title"
  end

  def test_a_phone_or_tablet_offers_neither
    show = Show.new(game: @game, layout: layout(400, 850), sounds: FakeSounds.new, radius: R)
    names = show.controls.map(&:name)

    refute_includes names, :fullscreen
    refute_includes names, :quit
    assert_nil show.title_plan.window_buttons
  end

  def test_full_screens_word_says_what_it_does
    words = Look::WORDS

    assert_equal "Full screen", words.fullscreen_button(false)
    assert_equal "Window", words.fullscreen_button(true)
    assert_equal "Quit", words.quit
  end

  private

  def click(name)
    reach = @show.reach_of(name) or flunk("the title offers no #{name}")
    @show.tap(reach.center_x, reach.center_y, by: :mouse)
  end

  def refute_window_buttons(where)
    names = @show.controls.map(&:name)
    refute_includes names, :fullscreen, where
    refute_includes names, :quit, where
  end
end
