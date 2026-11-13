# frozen_string_literal: true

require_relative "../presentation/inputs"
require "minitest/mock"

# The mouse, a finger, and the wheel, as Lota hands them to Shell::App,
# and what each does: a press counts where it lands, the moment it goes
# down, unless Game Over's pile waits for it; what the engine makes up is
# no press; a failing mouse's double click is dropped; and the words
# follow the hand. The App is given a Fixture's Show, and no window.
class PointerTest < Minitest::Test
  include Inputs

  P = DotPopper::Presentation

  # What only the engine can do, remembered: setdef's splash (as the
  # App's splash, which a press skips) and Game Over's pile
  # (Shell::Dragging).
  class FakeShell
    attr_reader :skips, :told

    def initialize = (@skips = 0) && (@told = [])
    def skip = (@skips += 1) && nil
    def press(key, x, y) = @told << [:press, key, x.round, y.round]
    def move(key, x, y) = @told << [:move, key, x.round, y.round]
    def release(key, x, y) = @told << [:release, key, x.round, y.round]
    def drop = @told << [:drop]
  end

  def setup
    require "lota"
    require "dot_popper/shell"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def test_a_click_with_a_main_button_presses_where_it_lands
    [1, 2, 3].each do |button|
      given
      click(*place(:stats), button:)

      assert show.stats?, button
      assert_equal P::InputKind::MOUSE, show.input
    end
  end

  def test_a_side_button_and_the_click_sdl_makes_up_for_a_finger_press_nothing
    given
    click(*place(:stats), button: 4)
    click(*place(:stats), made_up: true)

    assert show.on_home?
  end

  def test_the_made_up_click_still_takes_the_hidden_cursor_there
    given
    x, y = place(:stats)
    click(x, y, made_up: true)

    assert_equal [x, y], [cursor.x, cursor.y]
    refute cursor.visible
  end

  def test_any_press_during_the_splash_only_skips_it
    given(splash: true)
    click(*place(:stats))

    assert_equal 1, @shell.skips
    assert show.on_home?
    given(splash: true)
    touch(*place(:stats))

    assert_equal 1, @shell.skips
    assert show.on_home?
  end

  # The first click lands just beside Stats, the second 7 units on, on it.
  def test_a_failing_mouses_second_click_is_dropped
    given
    reach = show.reach_of(:stats)
    beside = [reach.x - 4, reach.center_y]
    on = [reach.x + 3, reach.center_y]
    assert_nil show.control_at(*beside)
    click(*beside)
    click(*on)

    assert show.on_home?, "a click at once after the last, within 8 units, is dropped wherever it lands"
    given
    click(*beside)
    at_time(5.5)
    click(*on)

    assert show.stats?, "half a second later it counts"
  end

  def test_a_finger_presses_where_it_lands
    given(os: "iOS")
    touch(*place(:stats))

    assert show.stats?
    assert_equal P::InputKind::TOUCH, show.input
  end

  def test_a_trackpads_touch_and_one_made_up_from_the_mouse_press_nothing
    given(os: "Windows")
    x, y = place(:stats)
    touch(x, y, device: "touchpad")
    touch(x, y, made_up: true)

    assert show.on_home?
  end

  def test_a_finger_drags_a_list_and_a_drag_from_a_row_does_not_open_it
    given(at: :achievements, os: "iOS", width: 400, height: 700)
    x, y = place(show.controls.find { it.name in [:achievement, _] }.name)
    touch_down(x, y)
    touch_move(x, y - 40)
    touch_up(x, y - 40)

    assert_nil show.dialog
    assert_operator show.scroll.offset, :>, 0
  end

  def test_the_wheel_scrolls_a_list
    given(at: :credits)
    wheel(-2)

    assert_operator show.credits.offset, :>, 0
  end

  def test_a_press_away_from_game_overs_buttons_waits_on_the_pile
    given(at: :game_over)
    mouse_down(5, 400)

    assert_equal [[:press, :mouse, 5, 400]], @shell.told
    mouse_move(50, 300)
    mouse_up(50, 300)

    assert_equal [[:move, :mouse, 50, 300], [:release, :mouse, 50, 300]], @shell.told.drop(1)
    assert show.game_over?
  end

  def test_a_deliberate_move_takes_the_words_to_the_mouse
    given
    show.input = P::InputKind::GAMEPAD
    mouse_move(300, 300)
    mouse_move(302, 301)

    assert_equal P::InputKind::GAMEPAD, show.input, "a jitter"
    mouse_move(330, 330)

    assert_equal P::InputKind::MOUSE, show.input
  end

  def test_no_move_counts_while_the_window_settles
    given
    show.input = P::InputKind::GAMEPAD
    at_time(0.2)
    mouse_move(300, 300)
    mouse_move(400, 400)

    assert_equal P::InputKind::GAMEPAD, show.input
  end

  def test_the_mouse_hovers_and_leaving_the_window_ends_it
    given
    x, y = place(:stats)
    mouse_move(x, y)

    assert_equal :stats, show.hovered
    mouse_left

    assert_nil show.hovered
  end

  def test_losing_focus_lets_everything_go
    given(at: :stats)
    show.tap(*place(:clear), by: :mouse)

    assert show.clearing.held?
    focus_lost

    refute show.clearing.held?
    assert_equal [[:drop]], @shell.told
  end

  private

  attr_reader :fixture

  def show = fixture.show

  def given(os: "Linux", at: :home, splash: false, width: 1200, height: 800, **options)
    @fixture = Fixture.new(os:, width:, height:, **options)
    @shell = FakeShell.new
    @app = DotPopper::Shell::App.allocate
    start = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    { show:, platform: fixture.platform, touch: fixture.platform.touch?, speaker: show.sounds, window: fixture.window,
      splash: (@shell if splash), input: DotPopper::Shell::LotaInput.new, hooks: nil, dragging: @shell, cursor: start,
      uptime: 5.0, chatter: P::Chatter.quiet(P::Style::CHATTER), game: nil }.each { @app.instance_variable_set(:"@#{_1}", _2) }
    reach(at)
  end

  def cursor = @app.instance_variable_get(:@cursor) || @app.instance_variable_get(:@inputs).cursor

  # How Lota calls the App: the mouse by LÖVE's button numbers, and
  # +made_up+ as its istouch; a finger, id 1, with its device's type.
  def mouse_down(x, y, button: 1, made_up: false) = @app.mouse_pressed(x, y, button, made_up)
  def mouse_up(x, y, button: 1, made_up: false) = @app.mouse_released(x, y, button, made_up)
  def mouse_move(x, y) = @app.mouse_moved(x, y, false)
  def touch_down(x, y, device: "touchscreen", made_up: false) = @app.touch_pressed(1, x, y, device, made_up)
  def touch_move(x, y) = @app.touch_moved(1, x, y, "touchscreen", false)
  def touch_up(x, y, device: "touchscreen", made_up: false) = @app.touch_released(1, x, y, device, made_up)
  def wheel(notches) = @app.wheel_moved(notches)
  def focus_lost = @app.focus(false)
  def mouse_left = @app.mouse_focus(false)

  # The frames' clock, unclamped, has reached +seconds+.
  def at_time(seconds) = @app.instance_variable_set(:@uptime, seconds)

  def click(x, y, button: 1, made_up: false)
    mouse_down(x, y, button:, made_up:)
    mouse_up(x, y, button:, made_up:)
  end

  def touch(x, y, device: "touchscreen", made_up: false)
    touch_down(x, y, device:, made_up:)
    touch_up(x, y, device:, made_up:)
  end

  def place(name)
    reach = show.reach_of(name) or flunk "#{name.inspect} is not on #{show.screen.class}"
    [reach.center_x, reach.center_y]
  end

  def reach(at)
    case at
    when :home then nil
    when :stats then show.open_stats
    when :achievements then show.open_achievements
    when :settings then show.open_settings
    when :credits then show.open_settings.then { show.open_credits }
    when :game_over
      show.play
      fixture.tick(DotPopper::Rules::STARTING_SECONDS + 1)
      fixture.tick(DotPopper::Rules::GAME_OVER_GRACE + 0.1)
    end
    fixture.tick(0.1)
  end
end
