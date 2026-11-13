# frozen_string_literal: true

require_relative "inputs"

# The keyboard, on every screen that answers it: each key a player
# presses, as the shell hands it over (Presentation::KeyPress: the game's
# name for it, and the modifier keys held), and what it does there
# (Presentation::InputHandler). Where a screen answers a key in more than
# one way, the order is pinned: a typed license key's letters are never
# shortcuts, Ctrl+V pastes before V is typed, and Alt+Enter is
# fullscreen's, not the main button's.
# Written against Shell::App#key_pressed before its chain moved here;
# only how a key reaches the game changed.
class KeyboardTest < Minitest::Test
  include Inputs

  # What only the engine can do, remembered: setdef's splash, quitting,
  # and switching fullscreen.
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

  # A license key's text ignores spaces, so one typed as it is printed,
  # in groups, keeps the offer open; with nothing typed, Space is the
  # offer's main button, Back. Escape closes it either way.
  def test_space_does_nothing_while_a_key_is_typed
    given(at: :offer)
    %i[a b space c].each { press(it) }

    assert show.offer?, "Space between a key's groups"
    assert_equal "ABC", fixture.storefront.typed
    press(:escape)

    refute show.offer?, "Escape closes it"
    assert_equal 0, @shell.quits
    given(at: :offer)
    press(:space)

    refute show.offer?, "nothing typed: Space is Back"
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

      assert show.sounds.muted?, "#{at}: Ctrl+M is no M"
    end
  end

  def test_h_on_home_opens_how_to_play
    given
    press(:h)

    assert show.tutorial?
    %i[ctrl alt command].each do |held|
      given
      press(:h, held)

      assert show.on_home?, "#{held}+H is no H"
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
    assert show.on_home?, "Ctrl+Enter is no Enter"
    given
    press(:space, :alt)

    assert show.on_home?, "Alt+Space is no Space"
  end

  # A key held with Ctrl, Cmd or Alt acts only where a table binds that
  # chord (Ctrl or Cmd with V or B, Alt or Cmd with Enter); elsewhere it
  # is no press of the plain key. On a license key, a key's letters are
  # typed with any of them held, so they are never shortcuts.
  def test_a_chord_is_not_the_plain_key
    { [:settings, :c] => -> { show.settings? }, [:keypad, :"2"] => -> { show.group_panel.code.empty? },
      [:credits, :down] => -> { show.credits.offset.zero? }, [:stats, :escape] => -> { show.stats? },
      [:home, :f11] => -> { @shell.switches.zero? }, [:home, :space] => -> { show.on_home? } }.each do |(at, key), still|
      %i[ctrl alt command].each do |held|
        given(at:, pro: at == :keypad)
        press(key, held)

        assert still.call, "#{held}+#{key} on #{at}"
        assert_equal 0, @shell.quits, "#{held}+#{key} on #{at}"
      end
    end
    given(at: :server, gone: true, copied: SERVER)
    press(:v, :ctrl, :alt)

    assert_nil fixture.server_choice.address, "Ctrl+Alt+V is no Ctrl+V"
    given(at: :offer)
    press(:m, :alt)
    press(:k, :command)

    assert_equal "MK", fixture.storefront.typed
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

  # Where a screen has no Back, Escape does what a controller's B does:
  # on Home a computer asks, and a second Escape (or B) within
  # Show::QUIT_ASK quits; in a game nothing, so no stray key ends one.
  # Android's Back, which arrives as Escape, leaves the app from Home at
  # once, as Back does on an app's first screen; iOS apps never quit.
  def test_escape_with_no_back_does_what_b_does
    ["Linux", "Windows", "OS X"].each do |os|
      given(os:)
      press(:escape)

      assert_equal 0, @shell.quits, "#{os}: the first Escape asks"
      assert_operator show.quit_prompt, :>, 0.0, os
      assert_equal "Press Escape again to quit", show.quit_again, os
      press(:escape)

      assert_equal 1, @shell.quits, "#{os}: the second Escape quits"
      given(os:, at: :game)
      press(:escape)
      press(:escape)

      assert_equal 0, @shell.quits, "#{os}: Escape in a game"
      assert show.playing?, os
    end
    { "Android" => 1, "iOS" => 0 }.each do |os, home|
      given(os:)
      press(:escape)

      assert_equal home, @shell.quits, "#{os}: Escape on Home"
      assert_equal 0.0, show.quit_prompt, os
      given(os:, at: :game)
      press(:escape)

      assert_equal 0, @shell.quits, "#{os}: Escape in a game"
      assert show.playing?, os
    end
  end

  def test_a_second_escape_quits_only_while_the_question_shows
    given
    press(:escape)
    fixture.tick(P::Show::QUIT_ASK + 0.5)
    press(:escape)

    assert_equal 0, @shell.quits, "too late: it asks again"
    assert_operator show.quit_prompt, :>, 0.0
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

  # A Show at +at+, on +os+, with a Fixture's other choices, and the
  # handler the shell hands its keys to.
  def given(os: "Linux", at: :home, splash: false, **options)
    @fixture = Fixture.new(os:, width: 1200, height: 800, **options)
    @shell = FakeShell.new(splash:)
    start = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    @handler = P::InputHandler.new(show:, platform: fixture.platform, shell: @shell, pile: nil, cursor: start)
    reach(at)
  end

  # The key the game calls +key+ (nil: one it doesn't name), pressed with
  # the modifier keys +held+.
  def press(key, *held) = @handler.call(P::KeyPress.new(key:, held:))

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
