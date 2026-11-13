# frozen_string_literal: true

require_relative "fake_engine"

# What the game is built from on every system and in every kind of build
# (Composition::Root), with memory saves and a fake engine, and no Lota:
# the window, the store, sharing and buzzing, the keys and receipts it
# trusts, the free games, the date and the server, and which developer
# settings a store build ignores. A test build (no channel) is the control.
class RootTest < Minitest::Test
  include PresentationTest

  C = DotPopper::Continuity
  B = DotPopper::Build
  Root = DotPopper::Composition::Root
  SYSTEMS = ["iOS", "Android", "OS X", "Windows", "Linux"].freeze
  BUILDS = [nil, *B::CHANNEL_NAMES].freeze
  PHONES = %w[iOS Android].freeze
  # Every developer setting a player could set that matters to a store.
  SETTINGS = {
    "DOT_POPPER_AUTOMATED" => "1", "DOT_POPPER_PRO" => "1", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SCENARIO" => "game",
    "DOT_POPPER_FREE_GAMES" => "999", "DOT_POPPER_TODAY" => "2031-01-01", "DOT_POPPER_SERVER" => "http://localhost:1"
  }.freeze

  # Quitting after a while makes a run automated in any build, as
  # DOT_POPPER_AUTOMATED does only in a test build (Automation).
  AUTOMATED = { "DOT_POPPER_QUIT_AFTER" => "600" }.freeze

  def root(system = "Linux", channel: nil, env: AUTOMATED, engine: FakeEngine.new(system))
    Root.new(engine:, settings: DotPopper::Composition::Settings.new(env, channel:))
  end

  def port(storefront) = storefront.instance_variable_get(:@port)

  def test_every_system_and_every_build_builds_a_game_at_home
    SYSTEMS.product(BUILDS).each do |system, channel|
      game = root(system, channel:)

      assert_instance_of DotPopper::Cabinet::Home, game.cabinet.state, "#{system}, #{channel.inspect}"
      assert_predicate game.show, :home?, "#{system}, #{channel.inspect}"
      assert_equal DotPopperTest.platform(system), game.platform
    end
  end

  def test_a_phone_fills_its_screen_and_a_computer_opens_a_window_with_its_controls
    SYSTEMS.each do |system|
      engine = FakeEngine.new(system)
      game = root(system, engine:)

      if PHONES.include?(system)
        assert_equal :filled, engine.opened, system
        assert_instance_of NoWindowControl, game.window, system
      else
        assert_equal({ radius: 50, wanted: nil, smallest: [400, 320] }, engine.opened, system)
        assert_instance_of FakeEngine::DesktopWindow, game.window, system
        refute game.window.exclusive, system
      end
    end
  end

  def test_a_computers_window_takes_the_size_and_the_fullscreen_asked_for_in_a_store_build_too
    BUILDS.each do |channel|
      engine = FakeEngine.new("Windows")
      game = root("Windows", channel:, engine:, env: { "DOT_POPPER_WINDOW" => "300x850", "DOT_POPPER_FULLSCREEN" => "exclusive" })

      assert_equal [400, 850], engine.opened[:wanted], "no smaller than the smallest window"
      assert game.window.exclusive, channel.inspect
    end
  end

  def test_the_lines_a_run_prints_name_the_dots_size_and_where_games_are_logged
    {
      "iOS" => "a dot's radius is 50 points, about 8 mm", "Android" => "a dot's radius is 50 dp, about 8 mm",
      "OS X" => "a dot's radius is 50 logical pixels", "Windows" => "a dot's radius is 50 logical pixels",
      "Linux" => "a dot's radius is 50 logical pixels"
    }.each do |system, line|
      engine = FakeEngine.new(system)
      root(system, engine:)

      assert_equal [line, "dots are sized to the screen as each game starts", "each game is logged in /save/games.csv"], engine.said, system
    end
    engine = FakeEngine.new("Linux")
    engine.file("dot_size.txt").write(DotPopper::DotSizing::STANDARD.name)
    root(engine:, env: { "DOT_POPPER_PERF" => "1" })

    refute_includes engine.said, "dots are sized to the screen as each game starts"
    assert_match(/\AEd25519 (verifies|does not verify) the server's test vector\z/, engine.said[1])
  end

  def test_only_android_buzzes_and_only_a_phone_shares_through_its_sheet
    SYSTEMS.each do |system|
      engine = FakeEngine.new(system)
      game = root(system, engine:)

      if system == "Android"
        assert_same engine.buzzer, game.haptics
      else
        assert_instance_of NoHaptics, game.haptics, system
      end
      if PHONES.include?(system)
        assert_instance_of SheetSharing, game.sharing, system
      else
        assert_instance_of InGameSharing, game.sharing, system
      end
    end
  end

  def test_a_phone_starts_with_touch_a_computer_with_the_mouse_and_a_fake_gamepad_with_the_gamepad
    assert_equal InputKind::TOUCH, root("iOS").show.input
    assert_equal InputKind::MOUSE, root("OS X").show.input
    game = root("Linux", env: { "DOT_POPPER_FAKE_GAMEPAD" => "1" })

    assert_equal InputKind::GAMEPAD, game.show.input
    assert game.cursor.visible
    refute root("Linux").cursor.visible
  end

  # Storefront.for's table (doc/design/store-and-pro.md), as the root
  # builds it on each system for each channel.
  def test_each_build_sells_through_its_own_store_on_each_system
    expected = {
      nil => { phone: :fake, computer: :fake_website },
      B::WEBSITE => { "iOS" => :native, "Android" => :website, computer: :website },
      B::MAC_APP_STORE => { phone: :native, "OS X" => :helper, computer: :none },
      B::MICROSOFT_STORE => { phone: :native, "Windows" => :helper, computer: :none },
      B::APP_STORE => { phone: :native, computer: :none },
      B::GOOGLE_PLAY => { phone: :native, computer: :none }
    }
    SYSTEMS.product(BUILDS).each do |system, channel|
      row = expected.fetch(channel)
      want = row.fetch(system) { row.fetch(PHONES.include?(system) ? :phone : :computer) }

      assert_equal want, store_kind(root(system, channel:).storefront), "#{system}, #{channel.inspect}"
    end
  end

  def store_kind(store)
    case store
    when NoStorefront then :none
    when WebsiteStore then store.instance_variable_get(:@checkout).is_a?(FakeCheckout) ? :fake_website : :website
    else
      case port(store)
      when FakeStore then :fake
      when NativeStore then :native
      when FakeEngine::StoreHelper then :helper
      end
    end
  end

  def test_a_computers_own_store_starts_no_helper_in_an_automated_run
    [B::MAC_APP_STORE, "OS X", B::MICROSOFT_STORE, "Windows"].each_slice(2) do |channel, system|
      helper = port(root(system, channel:).storefront)

      assert helper.automated, system
      refute port(root(system, channel:, env: {}).storefront).automated, system
    end
  end

  def test_a_store_build_trusts_setdefs_keys_though_the_environment_says_automated
    assert_same C::PINNED, root(channel: B::WEBSITE, env: SETTINGS).trusted_pins
    assert_same C::TEST_PINS, root(env: SETTINGS).trusted_pins
  end

  def test_a_test_signed_license_key_does_not_unlock_pro_in_a_store_build
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)

    refute key.valid?(root(channel: B::WEBSITE, env: SETTINGS).trusted_pins)
    assert key.valid?(root(env: SETTINGS).trusted_pins)
  end

  def test_only_a_test_build_takes_the_fake_stores_receipts
    receipt = DotPopper::Receipt.issue

    assert_same DotPopper::Receipt::STORES, root("iOS", channel: B::APP_STORE, env: SETTINGS).trusted_receipts
    refute DotPopper::Entitlement.new(trust: root("iOS", channel: B::APP_STORE, env: SETTINGS).trusted_receipts).prove(receipt)
    assert DotPopper::Entitlement.new(trust: root(env: SETTINGS).trusted_receipts).prove(receipt)
  end

  # Windows' word for a license is taken in the Microsoft Store's build
  # only, whose answers come down the helper's pipe and from no file.
  def test_only_the_microsoft_store_build_takes_windows_word
    word = "microsoft:#{DotPopper::Receipt::PRODUCT_ID}:9NBLGGH4R315/000N"
    trust = ->(channel) { root("Windows", channel:, env: SETTINGS).trusted_receipts }

    assert_same DotPopper::Receipt::MICROSOFT_STORE, trust.call(B::MICROSOFT_STORE)
    assert DotPopper::Entitlement.new(trust: trust.call(B::MICROSOFT_STORE)).prove(word)
    [nil, B::APP_STORE, B::MAC_APP_STORE, B::WEBSITE].each do |channel|
      refute DotPopper::Entitlement.new(trust: trust.call(channel)).prove(word), channel.inspect
    end
  end

  def test_pro_is_set_by_the_environment_only_in_a_test_build
    BUILDS.each do |channel|
      game = root("Linux", channel:, env: SETTINGS)

      assert_equal channel.nil?, game.entitlement.pro?, channel.inspect
    end
  end

  def test_the_free_game_limit_counts_in_a_store_build_even_for_a_bot_or_a_scenario
    assert_predicate root(channel: B::WEBSITE, env: SETTINGS), :player?
    refute_predicate root(env: SETTINGS), :player?
    refute_predicate root(env: { "DOT_POPPER_AUTOPLAY" => "1" }), :player?
    refute_predicate root(env: { "DOT_POPPER_SCENARIO" => "game" }), :player?
    assert_predicate root(env: { "DOT_POPPER_SCENARIO" => "game", "DOT_POPPER_FREE_GAMES" => "2" }), :player?
    assert_predicate root(env: {}), :player?
  end

  def test_a_store_build_starts_with_the_usual_free_games
    games = root(channel: B::WEBSITE, env: SETTINGS).free_games(DotPopper::Entitlement.free, metered: true, store: DotPopper::ScoreRecord::Memory.new)

    assert_equal DotPopper::FreeGames::BANK + DotPopper::FreeGames::DAILY, games.left
    test_build = root(env: SETTINGS).free_games(DotPopper::Entitlement.free, metered: true, store: DotPopper::ScoreRecord::Memory.new)

    assert_equal 999 * 2, test_build.left
  end

  def test_a_store_build_keeps_the_real_date_and_server
    store = root(channel: B::WEBSITE, env: SETTINGS)

    assert_equal Date.today, store.settings.today.call
    assert_nil store.server_url, "the bot's run is offline, not on DOT_POPPER_SERVER"
    assert_nil store.theme_feed
    plain = root(channel: B::WEBSITE, env: { "DOT_POPPER_SERVER" => "http://localhost:1" })

    assert_equal DotPopper::Network::Settings::SERVER_URL, plain.server_url
    test_build = root(env: SETTINGS)

    assert_equal Date.new(2031, 1, 1), test_build.settings.today.call
    assert_equal "http://localhost:1", test_build.server_url
    refute_nil test_build.theme_feed
  end

  # A license file on disk is never read in an app store's build, so it
  # grants nothing and the watch owes the server no request about it.
  def test_an_app_stores_build_never_reads_a_license_key_and_asks_the_server_nothing
    B::STORES.each do |channel|
      store = root(channel:, env: SETTINGS).license_store

      assert_instance_of DotPopper::ScoreRecord::Memory, store, channel
      assert_nil store.read, channel
      license = C::License.new(store, pins: C::TEST_PINS)

      refute_predicate license, :pro?, channel
      assert_nil license.due("n" * 16), channel
    end
    engine = FakeEngine.new("Linux")
    [B::WEBSITE, nil].each do |channel|
      assert_same engine.file("license.txt"), root(channel:, engine:, env: SETTINGS).license_store, channel.inspect
    end
  end

  def test_a_test_build_watches_for_setdef_through_its_fake_and_a_store_build_through_nothing_yet
    assert_instance_of C::Watch, root(env: SETTINGS).watch
    BUILDS.compact.each { assert_instance_of C::NoWatch, root(channel: it, env: SETTINGS).watch, it }
  end

  def test_a_scenarios_theme_is_used_in_a_test_build_and_ignored_in_a_store_build
    env = { "DOT_POPPER_PRO" => "1", "DOT_POPPER_THEME" => "ghost", "DOT_POPPER_THEME_UNLOCKS" => "ghost" }

    assert_equal :ghost, root(env:).pen.theme.key
    assert_equal :ghost, root(env:).speaker.theme.key
    refute_equal :ghost, root(channel: B::WEBSITE, env:).pen.theme.key
  end

  def test_the_pen_draws_without_shaders_when_asked_in_any_build
    BUILDS.each do |channel|
      assert root(channel:).pen.shaders
      refute root(channel:, env: { "DOT_POPPER_NO_SHADERS" => "1" }).pen.shaders, channel.inspect
    end
  end

  def test_the_splash_plays_unless_it_is_left_out_and_sounds_unless_muted
    assert root(env: {}).splash.sounding
    engine = FakeEngine.new("Linux")
    engine.file("sound.txt").write("muted")

    refute root(engine:, env: {}).splash.sounding
    assert_nil root(env: { "DOT_POPPER_NO_SPLASH" => "1" }).splash
  end

  def test_a_calm_run_has_a_calm_pile_in_any_build
    BUILDS.each do |channel|
      calm = root(channel:, env: { "DOT_POPPER_CALM" => "1" })

      assert_equal [Style::CALM_PILE, Style::CALM_GRAB, Style::CALM_TILT], [calm.pile_style, calm.grab_style, calm.tilt_style]
      plain = root(channel:)

      assert_equal [Style::PILE, Style::GRAB, Style::TILT], [plain.pile_style, plain.grab_style, plain.tilt_style]
    end
  end

  def test_the_bot_plays_when_asked_in_any_build
    BUILDS.each do |channel|
      refute_nil root(channel:, env: { "DOT_POPPER_AUTOPLAY" => "1" }).autopilot, channel.inspect
      assert_nil root(channel:).autopilot
    end
  end

  def test_starting_asks_the_phone_hosts_store_and_nothing_else_reaches_past_the_process
    engine = FakeEngine.new("iOS")
    game = root("iOS", channel: B::APP_STORE, engine:)

    assert_empty engine.opener.urls, "nothing asked before #start"
    game.start

    assert_equal ["dotpopper-store://open"], engine.opener.urls.map { it[/\A[^?]*/] }
  end

  # Coming back asks for the themes and the friend groups again, as at
  # launch, and nothing that is asked once each time the game starts: not
  # the store, nor the watch for setdef.
  def test_coming_back_asks_again_for_themes_and_groups_and_nothing_asked_once_a_start
    now = 0.0
    engine = FakeEngine.new("iOS")
    game = Root.new(engine:, settings: DotPopper::Composition::Settings.new(SETTINGS, channel: nil), clock: -> { now })
    asked = []
    game.theme_feed.define_singleton_method(:ask) { asked << :themes }
    game.show.group_panel.groups.define_singleton_method(:refresh) { asked << :groups }
    game.watch.define_singleton_method(:start) { asked << :watch }
    game.storefront.define_singleton_method(:connect) { asked << :store }
    game.start
    asked.clear
    now += DotPopper::Refresh::FLOOR
    game.refresh.came_back

    assert_equal %i[themes groups], asked
    now += DotPopper::Refresh::FLOOR
    game.cabinet.announce(DotPopper::Events::HomeShown.new(score_record: 0))

    assert_equal %i[themes groups themes groups], asked
  end

  # FakeEngine#file declares each name, as Shell::SaveFile does, so a
  # file the privacy document doesn't list fails every test here.
  def test_the_game_keeps_its_files_in_declared_save_files
    engine = FakeEngine.new("Linux")
    root(engine:)

    assert_includes engine.files.keys, "score_record.txt"
    assert_includes engine.files.keys, "games.csv"
  end

  # The root decides without Lota, and names nothing in the shell, which
  # hands it what it needs.
  def test_the_composition_root_names_neither_lota_nor_the_shell
    root = File.expand_path("../..", __dir__)
    named = Dir["#{root}/lib/dot_popper/composition/*.rb"].select do |path|
      File.readlines(path).any? { !it.lstrip.start_with?("#") && it.match?(/\bLota\b|\bShell::/) }
    end

    assert_empty named.map { it.delete_prefix("#{root}/") }
  end
end
