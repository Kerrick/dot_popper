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

  def player(name) = call(:post, "/v1/players", { name: })

  # A group created by +kai+, with +sam+ in it.
  def two_friends
    kai = player("Kai")
    sam = player("Sam")
    code = call(:post, "/v1/groups", {}, token: kai["token"])["group"]["code"]
    call(:post, "/v1/groups/join", { code: }, token: sam["token"])
    [kai, sam]
  end

  def play(who, score) = call(:post, "/v1/rounds", { score:, sized_to_screen: true }, token: who["token"])
  def state(who) = call(:get, "/v1/group", token: who["token"])["group"]
  def later(days) = @time += DAY * days

  def test_a_first_round_takes_the_vacant_trophy_and_tells_nobody
    kai, sam = two_friends

    assert play(kai, 20)["taken"]
    assert_equal "Kai", state(sam)["trophy"]["holder_name"]
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

    assert_equal [["Sam", 18]], news.map { [it["thief"], it["score"]] }
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
    kai = player("Kai")
    code = call(:post, "/v1/groups", {}, token: kai["token"])["group"]["code"]
    sam = player("Sam")

    call(:post, "/v1/groups/join", { code: " #{code.downcase}" }, token: sam["token"])

    assert_equal 6, code.length
    assert_equal 200, status
  end

  def test_a_group_is_small
    kai = player("Kai")
    code = call(:post, "/v1/groups", {}, token: kai["token"])["group"]["code"]
    7.times { call(:post, "/v1/groups/join", { code: }, token: player("P#{it}")["token"]) }

    assert_equal "group_full", call(:post, "/v1/groups/join", { code: }, token: player("Too")["token"])["error"]
  end

  def test_joining_guesses_are_limited
    sam = player("Sam")
    21.times { call(:post, "/v1/groups/join", { code: "NOPE22" }, token: sam["token"]) }

    assert_equal 429, status
  end

  def test_offensive_names_and_links_are_refused
    ["F U C K", "b1tch", "see www.x.com", "", "a" * 17].each do |name|
      player(name)

      assert_equal 422, status, name
    end
  end

  def test_ordinary_names_are_kept
    assert_equal 201, player("José O'Neil").then { status }
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
    call(:post, "/v1/members/#{sam["id"]}/report", {}, token: kai["token"])

    call(:delete, "/v1/players/me", token: sam["token"])

    assert_equal 204, status
    assert_equal 401, call(:get, "/v1/group", token: sam["token"]).then { status }
    assert_nil state(kai)["trophy"]["holder_id"]
    assert_empty state(kai)["news"]
    assert_empty @store.reports
    call(:delete, "/v1/players/me", token: kai["token"])
    assert_equal 204, status
  end

  def test_blocking_hides_a_name_and_a_blocked_thiefs_news
    kai, sam = two_friends
    play(kai, 20)
    call(:post, "/v1/members/#{sam["id"]}/block", {}, token: kai["token"])
    later(1)
    play(sam, 30)

    view = state(kai)

    assert_equal "Someone", view["members"].find { it["id"] == sam["id"] }["name"]
    assert_empty view["news"]
    assert_equal "Sam", state(sam)["members"].find(&->(m) { m["me"] })["name"]
  end

  def test_reports_block_at_once_and_two_hide_the_name_for_everyone
    kai, sam = two_friends
    third = player("Ann")
    code = state(kai)["code"]
    call(:post, "/v1/groups/join", { code: }, token: third["token"])
    call(:post, "/v1/members/#{sam["id"]}/report", {}, token: kai["token"])

    assert_equal "Someone", state(kai)["members"].find { it["id"] == sam["id"] }["name"]
    assert_equal "Sam", state(third)["members"].find { it["id"] == sam["id"] }["name"]

    call(:post, "/v1/members/#{sam["id"]}/report", {}, token: third["token"])

    refute_equal "Sam", state(third)["members"].find { it["id"] == sam["id"] }["name"]
    assert_equal 2, @store.reports.first["reports"]
  end

  def test_a_moderator_can_keep_a_name
    kai, sam = two_friends
    call(:post, "/v1/members/#{sam["id"]}/report", {}, token: kai["token"])

    @store.handle_report(sam["id"], hide: false)

    assert_empty @store.reports
  end

  def test_nobody_can_report_a_stranger
    kai = player("Kai")
    other = player("Sam")
    call(:post, "/v1/groups", {}, token: kai["token"])

    assert_equal "not_in_group", call(:post, "/v1/members/#{other["id"]}/report", {}, token: kai["token"])["error"]
  end

  def test_an_unknown_token_is_refused
    assert_equal "unknown_token", call(:get, "/v1/group", token: "nope")["error"]
  end

  def test_nonsense_is_refused
    post "/v1/players", "{", "CONTENT_TYPE" => "application/json"

    assert_equal 400, status
  end
end
