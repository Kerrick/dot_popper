# frozen_string_literal: true

require "minitest/autorun"
require "rack/test"
require "json"
require "dot_popper_server"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  DAY = 86_400

  def setup
    @time = Time.at(DAY * 1000)
    @store = DotPopperServer::Store.new(":memory:", clock: -> { @time })
  end

  def app = DotPopperServer::App.new(@store)

  def call(method, path, body = nil, token: nil)
    header "Authorization", token ? "Bearer #{token}" : nil
    send(method, path, body && JSON.generate(body), "CONTENT_TYPE" => "application/json")
    last_response.body.empty? ? nil : JSON.parse(last_response.body)
  end

  def status = last_response.status

  def player(*) = call(:post, "/v1/players", {})

  # A group created by +kai+, with +sam+ in it.
  def two_friends
    kai = player
    sam = player
    code = call(:post, "/v1/groups", { mark: 0 }, token: kai["token"])["group"]["code"]
    call(:post, "/v1/groups/join", { code:, mark: 1 }, token: sam["token"])
    [kai, sam]
  end

  def play(who, score) = call(:post, "/v1/rounds", { score:, sized_to_screen: true }, token: who["token"])
  def state(who) = call(:get, "/v1/group", token: who["token"])["group"]
  def later(days) = @time += DAY * days

  def test_a_first_round_takes_the_vacant_trophy_and_tells_nobody
    kai, sam = two_friends

    assert play(kai, 20)["taken"]
    assert_equal 0, state(sam)["trophy"]["holder_mark"]
    assert_empty state(kai)["news"]
    assert_empty state(sam)["news"]
  end

  def test_the_holders_score_falls_a_point_a_day_and_a_thief_tells_the_holder_once
    kai, sam = two_friends
    play(kai, 20)
    later(3)

    assert_equal 17, state(sam)["trophy"]["standing"]
    refute play(sam, 17)["taken"]
    assert play(sam, 18)["taken"]

    news = state(kai)["news"]

    assert_equal [[1, 18]], news.map { [it["thief"], it["score"]] }
    call(:post, "/v1/news/seen", { ids: news.map { it["id"] } }, token: kai["token"])
    assert_empty state(kai)["news"]
  end

  def test_a_holders_own_better_round_changes_nothing
    kai, = two_friends
    play(kai, 20)

    refute play(kai, 90)["taken"]
    assert_equal 20, state(kai)["trophy"]["score"]
  end

  def test_rounds_with_standard_dots_do_not_count
    kai, = two_friends

    assert_equal "round_does_not_count", call(:post, "/v1/rounds", { score: 10, sized_to_screen: false }, token: kai["token"])["error"]
  end

  def test_a_join_code_is_short_and_forgiving
    kai = player
    code = call(:post, "/v1/groups", {}, token: kai["token"])["group"]["code"]
    sam = player

    call(:post, "/v1/groups/join", { code: " #{code[0, 3]}-#{code[3..]}" }, token: sam["token"])

    assert_equal 7, code.length
    assert_match(/\A\d+\z/, code)
    assert_equal 200, status
  end

  def test_a_group_is_small
    kai = player
    code = call(:post, "/v1/groups", {}, token: kai["token"])["group"]["code"]
    7.times { call(:post, "/v1/groups/join", { code: }, token: player["token"]) }

    assert_equal "group_full", call(:post, "/v1/groups/join", { code: }, token: player["token"])["error"]
  end

  def test_joining_guesses_are_limited
    sam = player
    21.times { call(:post, "/v1/groups/join", { code: "0000000" }, token: sam["token"]) }

    assert_equal 429, status
  end

  def test_leaving_gives_up_the_trophy_and_keeps_the_group
    kai, sam = two_friends
    play(kai, 20)

    call(:delete, "/v1/groups/mine", token: kai["token"])

    assert_equal 204, status
    assert_nil state(sam)["trophy"]["holder_id"]
    assert_nil state(kai)
  end

  def test_deleting_takes_everything_and_ends_an_empty_group
    kai, sam = two_friends
    play(kai, 20)
    later(1)
    play(sam, 25)
    call(:delete, "/v1/players/me", token: sam["token"])

    assert_equal 204, status
    assert_equal 401, call(:get, "/v1/group", token: sam["token"]).then { status }
    assert_nil state(kai)["trophy"]["holder_id"]
    assert_empty state(kai)["news"]
    call(:delete, "/v1/players/me", token: kai["token"])
    assert_equal 204, status
  end

  def test_a_member_is_only_a_mark_and_each_is_the_groups_own
    kai, = two_friends
    third = player
    call(:post, "/v1/groups/join", { code: state(kai)["code"], mark: 0 }, token: third["token"])
    members = state(third)["members"]

    assert_equal [0, 1, 2], members.map { it["mark"] }
    assert_equal [2], members.select { it["me"] }.map { it["mark"] }
    assert_equal [:holder, :mark, :me], members.first.keys.map(&:to_sym).sort
  end

  def test_no_mark_asked_gets_the_first_free_one
    kai = player
    call(:post, "/v1/groups", {}, token: kai["token"])

    assert_equal [0], state(kai)["members"].map { it["mark"] }
  end

  def test_only_a_mark_from_the_list_is_accepted_never_text
    kai = player
    ["Kai", "0", 8, -1, 1.5, [0], { "a" => 1 }, true].each do |wanted|
      call(:post, "/v1/groups", { mark: wanted }, token: kai["token"])

      assert_equal 422, status, wanted.inspect
    end
    call(:post, "/v1/groups", { mark: 7 }, token: kai["token"])

    assert_equal [7], state(kai)["members"].map { it["mark"] }
  end

  def test_the_server_has_no_way_to_set_a_name_or_report_a_player
    kai = player
    call(:post, "/v1/players", { name: "Kai" })

    assert_equal 201, status
    assert_equal 404, call(:put, "/v1/players/me", { name: "Kai" }, token: kai["token"]).then { status }
    assert_equal 404, call(:post, "/v1/members/1/report", {}, token: kai["token"]).then { status }
    refute_includes @store.player(kai["token"]).keys, "name"
  end

  def test_an_unknown_token_is_refused
    assert_equal "unknown_token", call(:get, "/v1/group", token: "nope")["error"]
  end

  def test_nonsense_is_refused
    post "/v1/players", "{", "CONTENT_TYPE" => "application/json"

    assert_equal 400, status
  end
end
