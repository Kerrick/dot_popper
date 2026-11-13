# frozen_string_literal: true

require "test_helper"

class ServerSettingsTest < Minitest::Test
  Settings = DotPopper::Network::Settings

  def test_the_server_url_is_one_setting_for_every_build
    assert_equal Settings::SERVER_URL, Settings.server_url({})
    assert_nil Settings.server_url({ "DOT_POPPER_AUTOPLAY" => "1" }), "an automated run has no server"
    assert_nil Settings.server_url({ "DOT_POPPER_SCENARIO" => "game" })
    assert_nil Settings.server_url({ "DOT_POPPER_QUIT_AFTER" => "30" })
    assert_match(%r{\Ahttps://}, Settings::SERVER_URL)
    assert_equal "http://x:1", Settings.server_url({ "DOT_POPPER_SERVER" => "http://x:1" })
    assert_nil Settings.server_url({ "DOT_POPPER_SERVER" => "" })
  end
end
