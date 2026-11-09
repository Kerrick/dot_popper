# frozen_string_literal: true

require "test_helper"

# Every automated run stays off the internet: what happens in production
# can never change a test's result.
class AutomationTest < Minitest::Test
  Automation = DotPopper::Automation

  def test_runs_that_a_machine_drives_are_automated
    assert Automation.on?({ "DOT_POPPER_AUTOPLAY" => "1" })
    assert Automation.on?({ "DOT_POPPER_SCENARIO" => "game" })
    assert Automation.on?({ "DOT_POPPER_QUIT_AFTER" => "40" })
    assert Automation.on?({ "DOT_POPPER_SHOTS" => "1,5" })
    refute Automation.on?({})
  end

  def test_the_suite_cannot_reach_an_outside_host
    assert_raises(Automation::OutsideConnection) { TCPSocket.new("server.dot-popper.setdef.com", 443) }
    assert_raises(Automation::OutsideConnection) { Socket.tcp("example.com", 80) }
  end

  def test_the_group_link_cannot_reach_the_real_server_from_a_test
    link = DotPopper::Groups::Link.new(DotPopper::Groups::Settings::SERVER_URL)
    assert_raises(Automation::OutsideConnection) { link.call(:get, "/themes", nil, nil) }
  end

  def test_a_local_fake_is_allowed
    server = TCPServer.new("127.0.0.1", 0)
    socket = TCPSocket.new("127.0.0.1", server.addr[1])
    socket.close
    server.close
  end
end
