# frozen_string_literal: true

require_relative "test_helper"
require "dot_popper/presentation"

# A store build is decided by the build alone. Nothing a player can set, in
# the environment, a file or an argument, selects the test keys, grants Pro,
# changes the server, or skips the free-game limit in one
# (ADR-0010).
class BuildTest < Minitest::Test
  STORE = "website"
  SETTINGS = {
    "DOT_POPPER_AUTOMATED" => "1", "DOT_POPPER_PRO" => "1", "DOT_POPPER_SERVER" => "http://localhost:9292",
    "DOT_POPPER_FREE_GAMES" => "999", "DOT_POPPER_TODAY" => "2031-01-01", "DOT_POPPER_THEME_UNLOCKS" => "ghost",
    "DOT_POPPER_THEME" => "ghost", "DOT_POPPER_FAKE_SETDEF" => "here", "DOT_POPPER_FAKE_STORE_FAILS" => "buy",
    "DOT_POPPER_SCENARIO" => "game", "DOT_POPPER_SAVE_AS" => "elsewhere", "DOT_POPPER_GROUP_SCREEN" => "1",
    "DOT_POPPER_SOMETHING_NEW" => "1"
  }.freeze

  def test_a_store_build_ignores_every_setting_that_touches_purchases_pro_or_the_server
    settings = DotPopper::Build.settings(SETTINGS.merge("PATH" => "/bin"), channel: STORE)

    assert_equal({ "PATH" => "/bin" }, settings)
  end

  def test_a_store_build_keeps_the_settings_that_touch_nothing_of_the_kind
    kept = { "DOT_POPPER_CALM" => "1", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_QUIT_AFTER" => "20", "DOT_POPPER_WINDOW" => "400x850" }

    assert_equal kept, DotPopper::Build.settings(kept, channel: STORE)
  end

  def test_a_test_build_obeys_every_setting
    assert_equal SETTINGS, DotPopper::Build.settings(SETTINGS, channel: nil)
  end

  # Apple's and Google's rules: an app store's copy never takes a website
  # license key, and each of the four stores is named here.
  def test_the_app_stores_copies_take_no_license_key_and_the_website_and_a_test_build_do
    assert_equal %w[app-store mac-app-store google-play microsoft-store], DotPopper::Build::STORES
    DotPopper::Build::STORES.each { refute DotPopper::Build.license_keys?(it), it }
    assert DotPopper::Build.license_keys?("website")
    assert DotPopper::Build.license_keys?(nil)
  end

  def test_every_channel_is_named_once_and_the_storefront_uses_those_names
    assert_equal %w[app-store mac-app-store google-play microsoft-store website], DotPopper::Build::CHANNEL_NAMES
    storefront = DotPopper::Presentation::Storefront

    assert_equal [storefront::MAC_APP_STORE, storefront::MICROSOFT_STORE, storefront::WEBSITE],
                 [DotPopper::Build::MAC_APP_STORE, DotPopper::Build::MICROSOFT_STORE, DotPopper::Build::WEBSITE]
    assert_empty storefront::HELPER_CHANNELS - DotPopper::Build::CHANNEL_NAMES
  end

  def test_the_storefront_takes_its_channel_from_the_build
    assert_same DotPopper::Build::CHANNEL,DotPopper::Presentation::Storefront::BUILD_CHANNEL
  end

  def test_pro_and_the_server_stay_as_they_were_in_a_store_build
    env = DotPopper::Build.settings(SETTINGS, channel: STORE)

    refute DotPopper::Entitlement.forced?(env)
    assert_equal DotPopper::Network::Server::SERVER_URL, DotPopper::Network::Server.server_url(env)
    refute DotPopper::Automation.on?(env), "a store build is not made automated by the environment"
  end

  def test_the_settings_do_work_in_a_test_build
    env = DotPopper::Build.settings(SETTINGS, channel: nil)

    assert DotPopper::Entitlement.forced?(env)
    assert_equal "http://localhost:9292", DotPopper::Network::Server.server_url(env)
  end
end
