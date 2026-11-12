# frozen_string_literal: true

require "test_helper"

# The shell's own decisions in a store build, with every developer setting
# a player could set: the keys it trusts, whether the free-game limit
# counts, the day, and the settings it reads at all. A test build is the
# control.
class StoreBuildTest < Minitest::Test
  C = DotPopper::Continuity
  SETTINGS = {
    "DOT_POPPER_AUTOMATED" => "1", "DOT_POPPER_PRO" => "1", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SCENARIO" => "game",
    "DOT_POPPER_FREE_GAMES" => "999", "DOT_POPPER_TODAY" => "2031-01-01", "DOT_POPPER_SERVER" => "http://localhost:1"
  }.freeze

  def setup
    require "lota"
    require "dot_popper/shell"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  # An automated app guards the process so a stray connection ends it
  # with status 70; the suite's guard raises instead, so put it back.
  def teardown = DotPopper::Automation.guard!(exit_on_attempt: false)

  def app(channel) = DotPopper::Shell::App.new(SETTINGS, channel:)

  def test_a_store_build_trusts_setdefs_keys_though_the_environment_says_automated
    assert_same C::PINNED, app("website").send(:trusted_pins)
    assert_same C::TEST_PINS, app(nil).send(:trusted_pins)
  end

  def test_a_test_signed_license_key_does_not_unlock_pro_in_a_store_build
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)

    refute key.valid?(app("website").send(:trusted_pins))
    assert key.valid?(app(nil).send(:trusted_pins))
  end

  def test_only_a_test_build_takes_the_fake_stores_receipts
    receipt = DotPopper::Receipt.issue

    assert_same DotPopper::Receipt::STORES, app("app-store").send(:trusted_receipts)
    refute DotPopper::Entitlement.new(trust: app("app-store").send(:trusted_receipts)).prove(receipt)
    assert DotPopper::Entitlement.new(trust: app(nil).send(:trusted_receipts)).prove(receipt)
  end

  # Windows' word for a license is taken in the Microsoft Store's build
  # only, whose answers come down the helper's pipe and from no file.
  def test_only_the_microsoft_store_build_takes_windows_word
    word = "microsoft:#{DotPopper::Receipt::PRODUCT_ID}:9NBLGGH4R315/000N"
    microsoft = DotPopper::Presentation::Storefront::MICROSOFT_STORE

    assert_same DotPopper::Receipt::MICROSOFT_STORE, app(microsoft).send(:trusted_receipts)
    assert DotPopper::Entitlement.new(trust: app(microsoft).send(:trusted_receipts)).prove(word)
    [nil, "app-store", DotPopper::Presentation::Storefront::MAC_APP_STORE, "website"].each do |channel|
      refute DotPopper::Entitlement.new(trust: app(channel).send(:trusted_receipts)).prove(word), channel.inspect
    end
  end

  def test_a_computers_own_store_reads_its_helpers_pipe_and_an_automated_run_starts_none
    %w[OS\ X Windows].each do |os|
      port = app(DotPopper::Presentation::Storefront::MICROSOFT_STORE).send(:native_store, os)

      assert_instance_of DotPopper::Shell::StoreHelper, port, os
      assert_equal "-", port.path
      refute port.open("dotpopper-store://open?n=1"), "SETTINGS is an automated run"
    end
  end

  def test_the_free_game_limit_counts_in_a_store_build_even_for_a_bot_or_a_scenario
    assert app("website").send(:player?)
    refute app(nil).send(:player?)
  end

  def test_a_store_build_starts_with_the_usual_free_games
    games = app("website").send(:free_games, DotPopper::Entitlement.free, metered: true, store: DotPopper::ScoreRecord::Memory.new)

    assert_equal DotPopper::FreeGames::BANK + DotPopper::FreeGames::DAILY, games.left
  end

  def test_a_store_build_keeps_the_real_date_and_server
    store = app("website")

    assert_equal Date.today, store.send(:today).call
    assert_equal "", DotPopper::Groups::Settings.server_url(store.instance_variable_get(:@env)).to_s, "the bot's run is offline, not on DOT_POPPER_SERVER"
    plain = DotPopper::Shell::App.new({ "DOT_POPPER_SERVER" => "http://localhost:1" }, channel: "website").instance_variable_get(:@env)

    assert_equal DotPopper::Groups::Settings::SERVER_URL, DotPopper::Groups::Settings.server_url(plain)
    assert_equal Date.new(2031, 1, 1), app(nil).send(:today).call
  end

  # A license file on disk is never read in an app store's build, so it
  # grants nothing and the watch owes the server no request about it.
  def test_an_app_stores_build_never_reads_a_license_key_and_asks_the_server_nothing
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)
    DotPopper::Build::STORES.each do |channel|
      store = app(channel).send(:license_store)

      assert_instance_of DotPopper::ScoreRecord::Memory, store, channel
      assert_nil store.read, channel
      license = C::License.new(store, pins: C::TEST_PINS)

      refute_predicate license, :pro?, channel
      assert_nil license.due("n" * 16), channel
      assert_equal :entered, license.enter(key.text), "only a Paste Key could, and a store never shows it"
    end
    %w[website].push(nil).each do |channel|
      assert_instance_of DotPopper::Shell::SaveFile, app(channel).send(:license_store), channel.inspect
    end
  end
end
