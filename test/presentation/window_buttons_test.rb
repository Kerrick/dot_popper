# frozen_string_literal: true

require_relative "presentation_helper"

# A desktop's Home offers Quit, and its Settings the Display choice
# (Window, Borderless, Full screen), so a player with only a mouse can
# fill the screen, and leave a game that fills it, where the window's own
# buttons are gone. A click on either does its job at once; a phone or
# tablet offers neither.
class WindowButtonsTest < Minitest::Test
  include PresentationTest

  def setup
    @window = FakeWindow.new
    @cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    @show = new_show(cabinet: @cabinet, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, window: @window)
  end

  def test_each_display_choice_in_settings_moves_the_window_and_shows_as_chosen
    @show.open_settings
    %i[borderless exclusive window].each do |mode|
      click([:display, mode])
      assert_equal mode, @window.display
      chosen = @show.screens.fetch(:settings).plan.rows.find { it.key == :display }.choices.find { it[1] }
      assert_equal [:display, mode], chosen.last
    end
    assert @show.settings?, "Settings stays open"
  end

  def test_a_gamepads_rb_in_settings_steps_through_the_display_choices
    @show.open_settings
    @show.pad(:rb)
    assert_equal :borderless, @window.display
    @show.pad(:rb)
    assert_equal :exclusive, @window.display
    @show.pad(:rb)
    assert_equal :window, @window.display
  end

  # A labeled button pressed on purpose is no stray press, so it asks
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

  def test_the_mouse_over_quit_lights_it
    reach = @show.reach_of(:quit)
    @show.pointer_at(reach.center_x, reach.center_y)

    assert_equal :quit, @show.hovered
  end

  # Only Home offers Quit: Stats, Game Over and the rest each go back to
  # it, by a click on Back or Home, so a player in fullscreen with only a
  # mouse is never stuck there.
  def test_only_home_offers_quit
    @show.primary
    refute_includes names, :quit, "a game"
    @cabinet.update(30)
    @show.update(1.0)
    refute_includes names, :quit, "Game Over"
    assert @show.home_reach, "Game Over goes back Home"
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.back
    @show.open_stats
    refute_includes names, :quit, "the Stats screen"
    assert @show.back_reach, "Back goes back Home"
  end

  def test_a_phone_or_tablet_offers_neither
    show = new_show(cabinet: @cabinet, layout: layout(400, 850), sounds: FakeSounds.new, radius: R)
    refute_includes show.controls.map(&:name), :quit
    show.open_settings

    refute(show.screens.fetch(:settings).plan.rows.any? { it.key == :display })
  end

  def test_the_words_say_what_each_does
    words = Style::WORDS

    assert_equal "Quit", words.quit
    assert_equal %w[Window Borderless], %i[windowed full_screen_borderless].map { words.button(it) }
    assert_equal "Full screen", words.button(:full_screen)
  end

  private

  def names = @show.controls.map(&:name)

  def click(name)
    reach = @show.reach_of(name) or flunk("the screen offers no #{name.inspect}")
    @show.tap(reach.center_x, reach.center_y, by: :mouse)
  end
end
