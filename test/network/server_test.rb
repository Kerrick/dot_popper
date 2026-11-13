# frozen_string_literal: true

require "test_helper"

class NetworkServerTest < Minitest::Test
  Server = DotPopper::Network::Server

  def test_the_server_url_is_one_setting_for_every_build
    assert_equal Server::SERVER_URL, Server.server_url({})
    assert_nil Server.server_url({ "DOT_POPPER_AUTOPLAY" => "1" }), "an automated run has no server"
    assert_nil Server.server_url({ "DOT_POPPER_SCENARIO" => "game" })
    assert_nil Server.server_url({ "DOT_POPPER_QUIT_AFTER" => "30" })
    assert_match(%r{\Ahttps://}, Server::SERVER_URL)
    assert_equal "http://x:1", Server.server_url({ "DOT_POPPER_SERVER" => "http://x:1" })
    assert_nil Server.server_url({ "DOT_POPPER_SERVER" => "" })
  end
end
