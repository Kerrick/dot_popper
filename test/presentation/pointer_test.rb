# frozen_string_literal: true

require_relative "inputs"

# The mouse, a finger, and the wheel, as the shell hands them over
# (Presentation::MousePress and the rest), and what each does
# (Presentation::InputHandler): a press counts where it lands, the moment
# it goes down, unless Game Over's pile waits for it; what the engine
# makes up is no press; a failing mouse's double click is dropped; and the
# words follow the hand. Written against Shell::App's callbacks before
# they moved here; only how a press reaches the game changed.
class PointerTest < Minitest::Test
  include Inputs

  P = DotPopper::Presentation

  # What only the engine can do, remembered: setdef's splash and Game
  # Over's pile (Shell::Dragging).
  class FakeShell
    attr_reader :skips, :told

    def initialize(splash:)
      @splash = splash
      @skips = 0
      @told = []
    end

    def splash? = @splash
    def skip_splash = (@skips += 1) && (@splash = false)
    def press(key, x, y) = @told << [:press, key, x.round, y.round]
    def move(key, x, y) = @told << [:move, key, x.round, y.round]
    def release(key, x, y) = @told << [:release, key, x.round, y.round]
    def drop = @told << [:drop]
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

  def test_a_mouse_drags_a_list_too
    given(at: :achievements, width: 400, height: 700)
    x, y = place(show.controls.find { it.name in [:achievement, _] }.name)
    mouse_down(x, y)
    mouse_move(x, y - 40)
    mouse_up(x, y - 40)

    assert_nil show.dialog
    assert_operator show.scroll.offset, :>, 0
  end

  # Letting go ends a hold: "Clear my stats…" stops when the mouse
  # button or the finger comes up, before it clears anything.
  def test_letting_go_ends_a_hold
    { mouse: [method(:mouse_down), method(:mouse_up)], finger: [method(:touch_down), method(:touch_up)] }.each do |by, (down, up)|
      given(at: :stats)
      down.call(*place(:clear))

      assert show.clearing.held?, by
      up.call(*place(:clear))

      refute show.clearing.held?, "#{by}: let go"
    end
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

  def test_a_finger_drags_on_the_pile_too
    given(at: :game_over)
    touch_down(5, 400)
    touch_move(50, 300)
    touch_up(50, 300)

    assert_equal [[:press, 1, 5, 400], [:move, 1, 50, 300], [:release, 1, 50, 300]], @shell.told
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

  def test_a_resize_settles_the_window_again
    given
    show.input = P::InputKind::GAMEPAD
    @handler.resized(show.layout.whole)
    at_time(5.2)
    mouse_move(300, 300)
    mouse_move(400, 400)

    assert_equal P::InputKind::GAMEPAD, show.input, "settling after the resize"
    at_time(5.6)
    mouse_move(500, 500)

    assert_equal P::InputKind::MOUSE, show.input, "settled"
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
    @shell = FakeShell.new(splash:)
    start = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    @handler = P::InputHandler.new(show:, platform: fixture.platform, shell: @shell, pile: @shell, cursor: start)
    at_time(5.0)
    reach(at)
  end

  def cursor = @handler.cursor

  # The mouse's buttons by LÖVE's numbers, by the game's names (as
  # Shell::LotaInput turns them).
  MOUSE_BUTTONS = { 1 => :left, 2 => :right, 3 => :middle }.freeze

  # How the shell hands them over: the mouse by its buttons, and
  # +made_up+ where SDL made it up for a finger; a finger, id 1, with
  # whether a touchscreen's.
  def mouse_down(x, y, button: 1, made_up: false) = @handler.call(P::MousePress.new(x:, y:, button: mouse(button), made_up:))
  def mouse_up(x, y, button: 1, made_up: false) = @handler.call(P::MouseRelease.new(x:, y:, button: mouse(button), made_up:))
  def mouse_move(x, y) = @handler.call(P::MouseMove.new(x:, y:, made_up: false))
  def touch_down(x, y, device: "touchscreen", made_up: false) = @handler.call(P::TouchPress.new(id: 1, x:, y:, screen: device == "touchscreen", made_up:))
  def touch_move(x, y) = @handler.call(P::TouchMove.new(id: 1, x:, y:, screen: true, made_up: false))
  def touch_up(x, y, device: "touchscreen", made_up: false) = @handler.call(P::TouchRelease.new(id: 1, x:, y:, screen: device == "touchscreen", made_up:))
  def wheel(notches) = @handler.call(P::WheelTurn.new(notches:))
  def focus_lost = @handler.call(P::FocusLost.new)
  def mouse_left = @handler.call(P::MouseLeft.new)
  def mouse(number) = MOUSE_BUTTONS.fetch(number) { :"side#{number}" }

  # The frames' clock, unclamped, has reached +seconds+.
  def at_time(seconds) = @handler.instance_variable_set(:@uptime, seconds)

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
