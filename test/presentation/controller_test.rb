# frozen_string_literal: true

require_relative "inputs"

# A controller, on every screen: each button, both triggers and both
# sticks, as the shell hands them over (Presentation::ButtonPress and the
# rest, by the game's names), and what each does there
# (Presentation::InputHandler). A press at a place is A's, at the
# gamepad's cursor; every other button is the screen's own, labeled on it.
# Written against Shell::App's controller callbacks before they moved
# here; only how a button reaches the game changed (the tests still name
# each button as LÖVE does).
class ControllerTest < Minitest::Test
  include Inputs

  P = DotPopper::Presentation
  SERVER = "https://groups.example.org"

  # What only the engine can do, remembered: setdef's splash, quitting,
  # and Game Over's pile (Shell::Dragging), which presses away from its
  # buttons go to.
  class FakeShell
    attr_reader :quits, :skips, :told

    def initialize(splash:)
      @splash = splash
      @quits = @skips = 0
      @told = []
    end

    def splash? = @splash
    def skip_splash = (@skips += 1) && (@splash = false)
    def toggle_fullscreen = nil
    def quit = @quits += 1
    def press(key, x, y) = @told << [:press, key, x.round, y.round]
    def move(key, x, y) = @told << [:move, key, x.round, y.round]
    def release(key, x, y) = @told << [:release, key, x.round, y.round]
    def drop = @told << [:drop]
  end

  # A controller whose sticks and d-pad read what the test sets.
  class FakePad
    attr_accessor :axes, :dpad

    def initialize = (@axes = Hash.new(0.0)) && (@dpad = [])
    def gamepad? = true
    def gamepad_axis(name) = axes[name]
    def gamepad_down?(name) = dpad.include?(name)
  end

  def test_any_button_during_the_splash_only_skips_it
    %w[a b x y start back leftshoulder rightshoulder guide].each do |name|
      given(splash: true)
      button(name)

      assert_equal 1, @shell.skips, name
      assert show.on_home?, name
      refute cursor.visible, "#{name}: the splash hears it, not the game"
    end
  end

  # A trigger pulled to where it would press skips the splash and does
  # nothing else: not A under the splash (the right), not Friend groups
  # behind it (the left). Held on, it presses nothing once the splash is
  # gone, until it is let back and pulled again.
  def test_either_trigger_during_the_splash_only_skips_it
    %w[triggerright triggerleft].product([0.5, 1.0]).each do |axis, value|
      given(splash: true)
      trigger(axis, value)

      assert_equal 1, @shell.skips, "#{axis} at #{value}"
      assert show.on_home?, "#{axis} at #{value}"
      refute show.group_open?, "#{axis} at #{value}"
      refute cursor.visible, "#{axis} at #{value}: the splash hears it, not the game"
      assert_empty @shell.told, "#{axis} at #{value}"
      trigger(axis, 0.9)

      refute show.group_open?, "#{axis} still held"
      assert_empty @shell.told, "#{axis} still held"
    end
    given(splash: true)
    trigger("triggerright", 0.4)

    assert_equal 0, @shell.skips, "a trigger short of pressing is no press"
    given(splash: true)
    trigger("triggerleft", 1.0)
    trigger("triggerleft", 0.0)
    trigger("triggerleft", 1.0)

    assert show.group_open?, "let back and pulled again, once the splash is gone: Friend groups"
  end

  def test_any_button_shows_the_cursor_and_names_the_gamepad
    %w[guide leftstick dpup a].each do |name|
      given
      refute cursor.visible
      button(name)

      assert cursor.visible, name
      assert_equal P::InputKind::GAMEPAD, show.input, name
    end
  end

  def test_home
    { "start" => -> { show.playing? }, "x" => -> { show.stats? }, "y" => -> { show.tutorial? },
      "leftshoulder" => -> { show.achievements_open? }, "rightshoulder" => -> { show.themes? },
      "back" => -> { show.settings? } }.each do |name, done|
      given
      button(name)

      assert done.call, name
    end
    given
    trigger("triggerleft", 1.0)

    assert show.group_open?, "LT: Friend groups"
    given
    aim(*empty)
    button("a")

    assert show.playing?, "A at no button: Play"
  end

  def test_a_presses_the_button_under_the_cursor
    given
    aim(*place(:stats))
    button("a")
    release("a")

    assert show.stats?
    given
    aim(*place(:stats))
    trigger("triggerright", 1.0)
    trigger("triggerright", 0.0)

    assert show.stats?, "the right trigger is a second A"
  end

  def test_b_on_home_asks_then_quits_as_each_system_allows
    { "Linux" => 1, "Windows" => 1, "OS X" => 1, "Android" => 1, "iOS" => 0 }.each do |os, quits|
      given(os:)
      button("b")

      assert_equal 0, @shell.quits, "#{os}: the first B asks"
      assert_operator show.quit_prompt, :>, 0.0, os unless os == "iOS"
      assert_equal "Press B again to quit", show.quit_again, os unless os == "iOS"
      button("b")

      assert_equal quits, @shell.quits, "#{os}: the second B"
    end
  end

  def test_nothing_but_a_and_the_right_trigger_touches_a_game
    given(at: :game)
    score = show.cabinet.game.score
    %w[b x y start back leftshoulder rightshoulder].each { tap_button(it) }
    trigger("triggerleft", 1.0)

    assert show.playing?
    assert_equal score, show.cabinet.game.score
    assert_equal 0, @shell.quits
  end

  def test_game_over
    given(at: :game_over)
    button("start")

    assert show.playing?, "Start: Play again"
    given(at: :game_over)
    button("b")

    assert show.on_home?, "B: Home"
    given(at: :game_over)
    button("y")

    assert show.sharing?, "Y: Share my score"
    given(at: :game_over)
    aim(*empty)
    button("a")

    assert_equal [[:press, :gamepad, *empty.map(&:round)]], @shell.told, "A away from the buttons waits on the pile"
    assert show.game_over?
    release("a")

    assert_equal [:release, :gamepad, *empty.map(&:round)], @shell.told.last
  end

  def test_share_preview
    { "y" => -> { fixture.clipboard.text }, "b" => -> { !show.sharing? } }.each do |name, done|
      given(at: :share)
      button(name)

      assert done.call, name
    end
    given(at: :share)
    aim(*empty)
    button("a")

    assert fixture.clipboard.text, "A at no button: the main button, Copy"
  end

  def test_pages_go_back_with_b_and_start
    %i[stats achievements themes settings].each do |at|
      %w[b start].each do |name|
        given(at:)
        button(name)

        assert show.on_home?, "#{name} on #{at}"
      end
    end
    %i[credits privacy].each do |at|
      given(at:)
      button("b")

      assert show.settings?, "B on #{at} returns to Settings"
    end
  end

  def test_stats_y_holds_to_clear
    given(at: :stats)
    button("y")

    assert show.clearing.held?
    release("y")

    refute show.clearing.held?
  end

  def test_achievements
    given(at: :achievements)
    button("x")

    refute_nil show.dialog, "X: the first achievement"
    first = show.dialog
    button("rightshoulder")

    refute_equal first, show.dialog, "RB: the next"
    button("leftshoulder")

    assert_equal first, show.dialog, "LB: the previous"
    button("b")

    assert_nil show.dialog
    assert show.achievements_open?
  end

  def test_themes_step_with_the_shoulders
    given(at: :themes, pro: true)
    before = show.in_use
    button("rightshoulder")

    refute_equal before, show.in_use
    button("leftshoulder")

    assert_equal before, show.in_use
  end

  def test_settings
    { "back" => -> { show.sounds.muted? }, "rightshoulder" => -> { fixture.window.display != :window },
      "x" => -> { show.credits? }, "y" => -> { show.privacy? } }.each do |name, done|
      given(at: :settings)
      button(name)

      assert done.call, name
    end
  end

  def test_privacy
    given(at: :privacy)
    button("x")

    assert_equal [DotPopper::Presentation::Show::PRIVACY_URL], fixture.opener.urls
  end

  def test_credits_scroll_with_either_stick_and_the_cursor_waits
    given(at: :credits)
    at = cursor
    frames(0.5) { @pad.axes[:lefty] = 1.0 }

    assert_operator show.credits.offset, :>, 0, "the left stick reads on"
    assert_equal [at.x, at.y], [cursor.x, cursor.y]
    given(at: :credits)
    frames(0.5) { @pad.axes[:righty] = 1.0 }

    assert_operator show.credits.offset, :>, 0, "the right stick too"
    given(at: :credits)
    frames(0.5) { @pad.dpad = [:dpdown] }

    assert_operator show.credits.offset, :>, 0, "and the d-pad"
  end

  def test_the_left_stick_moves_the_cursor_elsewhere
    given
    at = cursor.x
    frames(0.3) { @pad.axes[:leftx] = 1.0 }

    assert_operator cursor.x, :>, at
    assert_equal P::InputKind::GAMEPAD, show.input
  end

  def test_the_offer
    given(at: :offer)
    button("y")

    assert_match(/\ADP-/, fixture.clipboard.text, "Y: Buy")
    given(at: :offer, copied: key_for_sale)
    button("x")

    assert fixture.entitlement.pro?, "X: Paste license key, on a copy that takes one"
    %w[start b].each do |name|
      given(at: :offer)
      button(name)

      refute show.offer?, name
    end
    given(at: :offer)
    aim(*empty)
    button("a")

    refute show.offer?, "A at no button: Back"
  end

  def test_the_tutorial_skips_with_b
    given(at: :tutorial)
    button("b")

    refute show.tutorial?
  end

  def test_friend_groups
    given(at: :groups, pro: true)
    button("x")

    assert_equal :join, show.group_panel.asking || show.group_panel.page, "X on the list: Join, after its notice"
    given(at: :keypad, pro: true)
    %w[2 3].each { show.group_panel.type(it.to_sym) }
    button("x")

    assert_equal "2", show.group_panel.code, "X on the keypad: Delete"
    button("b")

    assert_equal :list, show.group_panel.page, "B: Back"
  end

  def test_a_and_the_right_trigger_together_are_one_press
    given(at: :game_over)
    aim(*empty)
    button("a")
    trigger("triggerright", 1.0)
    release("a")

    assert_equal [:press], @shell.told.map(&:first), "still held by the trigger"
    trigger("triggerright", 0.0)

    assert_equal %i[press release], @shell.told.map(&:first)
  end

  def test_the_trigger_presses_once_until_let_back
    given(at: :game_over)
    aim(*empty)
    trigger("triggerright", 0.6)
    trigger("triggerright", 0.4)
    trigger("triggerright", 0.9)

    assert_equal [:press], @shell.told.map(&:first)
    trigger("triggerright", 0.2)

    assert_equal %i[press release], @shell.told.map(&:first)
  end

  def test_unplugging_lets_a_go
    given(at: :game_over)
    aim(*empty)
    button("a")
    unplug

    assert_equal %i[press release], @shell.told.map(&:first)
  end

  def test_an_axis_that_is_no_trigger_does_nothing
    given
    trigger("leftx", 1.0)

    refute cursor.visible
    assert show.on_home?
  end

  private

  attr_reader :fixture

  def show = fixture.show

  # LÖVE's names for an Xbox pad's buttons and triggers, by the game's
  # (as Shell::LotaInput turns them).
  BUTTONS = { "a" => :a, "b" => :b, "x" => :x, "y" => :y, "start" => :start, "back" => :select,
              "leftshoulder" => :lb, "rightshoulder" => :rb }.freeze
  TRIGGERS = { "triggerleft" => :left, "triggerright" => :right }.freeze

  # A Show at +at+, on +os+, with a Fixture's other choices, and the
  # handler the shell hands its controller to.
  def given(os: "Linux", at: :home, splash: false, **options)
    @fixture = Fixture.new(os:, width: 1200, height: 800, **options)
    @shell = FakeShell.new(splash:)
    @pad = FakePad.new
    start = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    @handler = P::InputHandler.new(show:, platform: fixture.platform, shell: @shell, pile: @shell, cursor: start)
    reach(at)
  end

  def cursor = @handler.cursor

  def button(name) = @handler.call(P::ButtonPress.new(button: BUTTONS[name]))
  def release(name) = @handler.call(P::ButtonRelease.new(button: BUTTONS[name]))
  def trigger(axis, value) = @handler.call(TRIGGERS[axis]&.then { P::TriggerPull.new(trigger: it, value:) })
  def unplug = @handler.call(P::GamepadRemoved.new)

  def tap_button(name)
    button(name)
    fixture.tick(0.05)
    release(name)
  end

  # The cursor moved to +x+, +y+, as the fake drag moves it.
  def aim(x, y) = @handler.fake_pad(:move, x, y)

  # Frames of +seconds+ with the sticks and d-pad as the block sets them,
  # read as Shell::Gamepads reads them, and handed over as Shell::App#update
  # does.
  def frames(seconds)
    yield
    step = 1 / 60.0
    stick = P::Stick.new(x: @pad.axes[:leftx], y: @pad.axes[:lefty]) +
            P::Stick.dpad(left: @pad.dpad.include?(:dpleft), right: @pad.dpad.include?(:dpright),
                          up: @pad.dpad.include?(:dpup), down: @pad.dpad.include?(:dpdown))
    right_stick = P::Stick.new(x: @pad.axes[:rightx], y: @pad.axes[:righty])
    (seconds / step).round.times do
      @handler.update(step, step, stick:, right_stick:)
      fixture.tick(step)
    end
  end

  def empty = [5.0, show.layout.height / 2.0]

  def place(name)
    reach = show.reach_of(name) or flunk "#{name.inspect} is not on #{show.screen.class}"
    [reach.center_x, reach.center_y]
  end

  def reach(at)
    case at
    when :home then nil
    when :stats then show.open_stats
    when :achievements then show.open_achievements
    when :themes then show.open_themes
    when :settings then show.open_settings
    when :credits then show.open_settings.then { show.open_credits }
    when :privacy then show.open_settings.then { show.open_privacy }
    when :offer then show.open_offer
    when :groups then show.group_panel.open
    when :keypad then open_keypad
    when :game then show.play
    when :game_over, :share then game_over(share: at == :share)
    when :tutorial then show.how_to_play
    end
    fixture.tick(0.1)
  end

  def open_keypad
    show.group_panel.open
    show.group_panel.pad(:x)
    show.group_panel.primary if show.group_panel.asking
  end

  def game_over(share:)
    show.play
    fixture.tick(DotPopper::Rules::STARTING_SECONDS + 1)
    fixture.tick(DotPopper::Rules::GAME_OVER_GRACE + 0.1)
    show.pad(:y) if share
  end

  def key_for_sale
    clipboard = P::MemoryClipboard.new
    DotPopper::FakeCheckout.new(clipboard:).buy
    clipboard.text
  end
end
