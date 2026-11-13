# frozen_string_literal: true

require_relative "../presentation/inputs"
require "minitest/mock"

# The keyboard, on every screen that answers it: each key a player
# presses, as Lota hands it to Shell::App#key_pressed (by LÖVE's name,
# with the modifier keys Lota::Keyboard says are held), and what it does
# there. Where a screen answers a key in more than one way, the order is
# pinned: a typed license key's letters are never shortcuts, Ctrl+V pastes
# before V is typed, and Alt+Enter is fullscreen's, not the main button's.
# The App is given a Fixture's Show, and no window.
class KeyboardTest < Minitest::Test
  include Inputs

  # What only the engine can do, remembered: setdef's splash (as the
  # App's splash, which a key skips), quitting, and switching fullscreen
  # (as the App's window).
  class FakeShell
    attr_reader :quits, :switches, :skips

    def initialize(splash:)
      @splash = splash
      @quits = @switches = @skips = 0
    end

    def splash? = @splash
    def skip_splash = (@skips += 1) && (@splash = false)
    def quit = @quits += 1
    def toggle_fullscreen = @switches += 1
    def skip = (@skips += 1) && nil
  end

  def setup
    require "lota"
    require "dot_popper/shell"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def test_any_key_during_the_splash_only_skips_it
    [:m, :escape, :enter, :f11, nil].each do |key|
      given(splash: true)
      press(key)

      assert_equal 1, @shell.skips, key.inspect
      assert_nothing_else_happened(key)
    end
  end

  # Until a pointer or a controller is used, Buy names the key that
  # presses it, after any key at all, one the game names or not.
  def test_a_computers_keyboard_makes_buy_name_its_key
    { "Linux" => "(Ctrl+B)", "Windows" => "(Ctrl+B)", "OS X" => "(⌘B)" }.each do |os, hint|
      [:tab, nil].each do |key|
        given(os:, at: :offer)
        refute_includes show.buy_label, hint, os
        press(key)

        assert_includes show.buy_label, hint, "#{os} #{key.inspect}"
      end
    end
    given(os: "Windows", at: :offer)
    press(:tab)
    show.input = P::InputKind::MOUSE

    refute_includes show.buy_label, "Ctrl+B", "a pointer takes the words back"
  end

  def test_ctrl_or_cmd_v_pastes_where_a_screen_takes_a_paste
    %i[ctrl command].each do |held|
      given(at: :offer, copied: key_for_sale)
      press(:v, held)

      assert fixture.entitlement.pro?, "#{held}+V pastes the license key"
      assert_empty fixture.storefront.typed

      given(at: :server, gone: true, copied: SERVER)
      press(:v, held)

      assert_equal SERVER, fixture.server_choice.address, "#{held}+V pastes the server's address"
    end
    given(at: :server, gone: true, copied: SERVER)
    press(:v)
    press(:v, :alt)

    assert_nil fixture.server_choice.address, "V alone, or with Alt, is no paste"
  end

  def test_a_paste_that_is_no_chord_is_typed_on_a_license_key
    given(at: :offer, copied: key_for_sale)
    press(:v)
    press(:v, :alt)

    assert_equal "VV", fixture.storefront.typed
    refute fixture.entitlement.pro?
  end

  def test_ctrl_or_cmd_b_buys_on_the_offer
    %i[ctrl command].each do |held|
      given(at: :offer)
      press(:b, held)

      assert_match(/\ADP-/, fixture.clipboard.text, "#{held}+B buys, and the test build's checkout copies a key")
      assert_empty fixture.storefront.typed
    end
    given(at: :offer)
    press(:b)

    assert_equal "B", fixture.storefront.typed, "B alone is typed"
    assert_nil fixture.clipboard.text
  end

  # A license key's letters, digits and hyphen are typed, whatever else
  # those keys do on another screen, and Backspace takes one away.
  def test_a_license_keys_characters_are_typed_and_never_shortcuts
    given(at: :offer)
    %i[m h c 7 minus x].each { press(it) }
    press(:m, :ctrl)
    press(:backspace)

    assert_equal "MHC7-X", fixture.storefront.typed
    refute show.sounds.muted?
    assert show.offer?
    assert_equal 0, @shell.quits
  end

  def test_enter_enters_a_typed_license_key_and_else_closes_the_offer
    given(at: :offer)
    press(:enter)

    refute show.offer?, "nothing typed: Enter is the offer's main button, Back"

    given(at: :offer)
    %i[a b c].each { press(it) }
    press(:enter)

    assert show.offer?
    refute_equal :ready, fixture.storefront.status, "entered, and found to be no key"
  end

  def test_space_and_escape_close_the_offer_while_a_key_is_typed
    %i[space escape].each do |key|
      given(at: :offer)
      press(:a)
      press(key)

      refute show.offer?, key
      assert_equal 0, @shell.quits
    end
  end

  def test_the_join_keypad_takes_digits_and_backspace
    given(at: :keypad, pro: true)
    %i[2 3 4 9 backspace 5].each { press(it) }
    press(:delete)
    press(:a)

    assert_equal "234", show.group_panel.code
    press(:m)

    assert show.sounds.muted?, "M is not a digit, so it switches sound"
  end

  def test_m_switches_sound_wherever_nothing_is_typed
    %i[home stats settings credits game game_over share tutorial].each do |at|
      given(at:)
      press(:m)

      assert show.sounds.muted?, at
      press(:m, :ctrl)

      refute show.sounds.muted?, "#{at}: Ctrl+M too"
    end
  end

  def test_h_on_home_opens_how_to_play
    [[], [:ctrl], [:alt]].each do |held|
      given
      press(:h, *held)

      assert show.tutorial?, held.inspect
    end
    %i[stats settings game_over].each do |at|
      given(at:)
      screen = show.screen
      press(:h)

      assert_same screen, show.screen, at
    end
  end

  def test_c_in_settings_opens_credits
    given(at: :settings)
    press(:c)

    assert show.credits?
    given
    press(:c)

    assert show.on_home?, "C on Home does nothing"
  end

  def test_the_scroll_keys_scroll_a_list
    given(at: :credits)
    at = -> { show.credits.offset }
    press(:down)
    down = at.call

    assert_operator down, :>, 0
    press(:page_down)

    assert_operator at.call, :>, down
    press(:end)
    bottom = at.call
    press(:page_up)

    assert_operator at.call, :<, bottom
    press(:up)
    press(:home)

    assert_in_delta 0.0, at.call
    assert show.credits?
  end

  def test_enter_and_space_press_the_main_button
    { home: -> { show.playing? }, stats: -> { show.on_home? }, game_over: -> { show.playing? }, share: -> { fixture.clipboard.text },
      new_theme: -> { !show.arrival? }, settings: -> { show.on_home? } }.each do |at, done|
      %i[enter space].each do |key|
        given(at:, arrival: at == :new_theme)
        press(key)

        assert done.call, "#{key} on #{at}"
      end
    end
  end

  def test_the_main_button_is_not_pressed_during_a_game
    given(at: :game)
    score = show.cabinet.game.score
    %i[enter space].each { press(it) }

    assert show.playing?
    assert_equal score, show.cabinet.game.score
  end

  def test_alt_or_cmd_enter_switches_fullscreen_and_ctrl_enter_does_not
    %i[alt command].each do |held|
      given
      press(:enter, held)

      assert_equal 1, @shell.switches, held
      assert show.on_home?, "#{held}+Enter does not Play"
    end
    given
    press(:enter, :ctrl)

    assert_equal 0, @shell.switches
    assert show.playing?, "Ctrl+Enter is Enter"
    given
    press(:space, :alt)

    assert show.playing?, "Alt+Space is Space"
  end

  def test_f11_switches_fullscreen_on_a_computer_only
    %w[Linux Windows OS X].each do |os|
      given(os:)
      press(:f11)

      assert_equal 1, @shell.switches, os
    end
    %w[iOS Android].each do |os|
      given(os:)
      press(:f11)
      press(:enter, :alt)

      assert_equal 0, @shell.switches, os
    end
  end

  def test_escape_goes_back_where_a_screen_has_back
    { stats: -> { show.on_home? }, credits: -> { show.settings? }, game_over: -> { show.on_home? }, offer: -> { !show.offer? },
      share: -> { !show.sharing? }, tutorial: -> { !show.tutorial? }, new_theme: -> { !show.arrival? },
      keypad: -> { show.group_panel.page == :list } }.each do |at, done|
      %w[Linux Android].each do |os|
        given(os:, at:, arrival: at == :new_theme, pro: at == :keypad)
        press(:escape)

        assert done.call, "#{os}: Escape on #{at}"
        assert_equal 0, @shell.quits, "#{os}: Escape on #{at}"
      end
    end
  end

  # With no Back, Escape quits a computer's game, during a game too, and
  # Android's Back leaves the app from Home only; iOS apps never quit.
  def test_escape_with_no_back_quits_as_each_system_does
    { "Linux" => [1, 1], "Windows" => [1, 1], "OS X" => [1, 1], "Android" => [1, 0], "iOS" => [0, 0] }.each do |os, (home, game)|
      given(os:)
      press(:escape)

      assert_equal home, @shell.quits, "#{os}: Escape on Home"
      given(os:, at: :game)
      press(:escape)

      assert_equal game, @shell.quits, "#{os}: Escape in a game"
      assert show.playing?, os
    end
  end

  def test_a_key_the_game_does_not_name_does_nothing_else
    given
    press(nil)
    press(:tab)

    assert_nothing_else_happened(:tab)
  end

  private

  P = DotPopper::Presentation
  SERVER = "https://groups.example.org"

  attr_reader :fixture

  def show = fixture.show

  # LÖVE's names for the modifier keys, by the game's.
  HELD = { ctrl: :lctrl, alt: :lalt, command: :lgui }.freeze

  # A Show at +at+, on +os+, with a Fixture's other choices, in an App
  # that Lota hands its keys to.
  def given(os: "Linux", at: :home, splash: false, **options)
    @fixture = Fixture.new(os:, width: 1200, height: 800, **options)
    @shell = FakeShell.new(splash:)
    @app = DotPopper::Shell::App.allocate
    { show:, platform: fixture.platform, touch: fixture.platform.touch?, speaker: show.sounds, window: @shell,
      splash: (@shell if splash), input: DotPopper::Shell::LotaInput.new, hooks: nil }.each { @app.instance_variable_set(:"@#{_1}", _2) }
    reach(at)
  end

  # The key the game calls +key+ (nil: one it doesn't name), pressed with
  # the modifier keys +held+, as Lota calls the App.
  def press(key, *held)
    name = key.nil? ? "f1" : DotPopper::Shell::LotaInput::KEYS.key(key) || key.to_s
    down = ->(*keys) { held.any? { keys.include?(HELD.fetch(it)) } }
    Lota::Keyboard.stub(:down?, down) { Lota::Event.stub(:quit, -> { @shell.quit }) { @app.key_pressed(name) } }
  end

  def reach(at)
    case at
    when :home then nil
    when :stats then show.open_stats
    when :settings then show.open_settings
    when :credits then show.open_settings.then { show.open_credits }
    when :server then show.open_settings.then { show.open_server }
    when :offer then show.open_offer
    when :keypad then open_keypad
    when :game then show.play
    when :game_over, :share then game_over(share: at == :share)
    when :tutorial then show.how_to_play
    when :new_theme then nil
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

  # A license key the test build's checkout would sell.
  def key_for_sale
    clipboard = P::MemoryClipboard.new
    P::FakeCheckout.new(clipboard:).buy
    clipboard.text
  end

  def assert_nothing_else_happened(key)
    assert show.on_home?, key.inspect
    refute show.sounds.muted?, key.inspect
    assert_equal 0, @shell.quits, key.inspect
    assert_equal 0, @shell.switches, key.inspect
  end
end
