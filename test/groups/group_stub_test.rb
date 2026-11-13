# frozen_string_literal: true

require "test_helper"
require_relative "../../script/group_stub"

# script/group_stub.rb, the stand-in server for trying the screens by
# hand, answers every request friend groups declare, so a new one cannot
# be missed there.
class GroupStubTest < Minitest::Test
  # What each declared field carries here. A field not named here fails
  # the test, so the stub is looked at when one is added.
  SAMPLES = { join_code: "1234567", key: "steady", score: 10 }.freeze

  def test_every_declared_request_is_answered
    DotPopper::Groups::REQUESTS.each_value do |request|
      stub = GroupStub.new
      token = "Bearer #{stub.call('POST', '/player', {}, nil).body[:token]}" if request.token
      # Group 2 is one the stub's player is in.
      path = request.path.sub(":id", "2")
      reply = stub.call(request.verb.to_s.upcase, path, request.body.keys.to_h { [it.to_s, SAMPLES.fetch(it)] }, token)

      assert reply.status.between?(200, 299), "#{request.kind}: #{request.verb.upcase} #{path} answered #{reply.status}"
    end
  end

  def test_an_achievement_shows_in_each_group_history
    stub = GroupStub.new
    token = "Bearer #{stub.call('POST', '/player', {}, nil).body[:token]}"
    stub.call("POST", "/achievements", { "key" => "steady" }, token)
    history = JSON.parse(JSON.generate(stub.call("GET", "/groups/2/history", {}, token).body))

    assert_equal 1, history.filter_map { DotPopper::Groups::MemberAchievement.parse(it) }.size
  end
end
