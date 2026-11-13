# frozen_string_literal: true

require "test_helper"

class SessionTest < Minitest::Test
  Groups = DotPopper::Groups
  Reply = DotPopper::Network::Reply

  # A worker that holds each job until the test answers it.
  class HandWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  def setup
    @store = DotPopper::ScoreRecord::Memory.new
    @worker = HandWorker.new
    @time = Time.at(1_000_000)
    @session = new_session
  end

  def new_session = Groups::Session.new(store: @store, worker: @worker, clock: -> { @time })
  def pump = @session.update(quiet: true)
  def job = @worker.started.first.first
  def paths = @worker.started.map { it.first.path }

  def group(id: 1, you: 2, champion: 1, top: 50, numbers: [1, 2])
    { "id" => id, "join_code" => "2345678", "you" => you, "champion_number" => champion, "top_score" => top,
      "reign_started_at" => "2026-11-01T00:00:00Z", "members" => numbers.map { { "number" => it, "top_score" => it * 10 } } }
  end

  def change(id, champion: 1, previous: nil, score: 50, passed_on: :unsaid)
    entry = { "id" => id, "champion_number" => champion, "previous_champion_number" => previous, "score" => score, "at" => "2026-11-05T10:00:00Z" }
    entry["passed_on"] = passed_on unless passed_on == :unsaid
    entry
  end

  def answer(status, body = {}, retry_after: nil)
    @worker.answer(Reply.new(status:, body:, retry_after:))
    pump
  end

  # Becomes a player, joins, and hears the group and its empty history.
  def joined(body = group, changes: [])
    @session.join("2345678")
    pump
    unless @session.known?
      answer(201, { "token" => "t" })
      pump
    end
    answer(201, body)
    pump
    answer(200, changes)
    pump
  end

  def played(score: 60)
    @session.game_finished(score:, sized_to_screen: true)
    pump
  end

  def refreshed(body = [group], changes: nil)
    @session.refresh
    pump
    answer(200, body)
    pump
    answer(200, changes) if changes
    pump
  end

  def test_a_new_player_asks_nothing
    @session.refresh
    pump

    assert_empty @worker.started
  end

  def test_joining_becomes_a_player_first_and_remembers_them
    joined

    assert_predicate @session, :member?
    assert_equal "t", new_session.token
    assert_equal 1, @session.take_arrival
    assert_nil @session.take_arrival
  end

  def test_a_player_sends_only_a_join_code
    @session.join("2345678")
    pump

    assert_equal ["/player", nil], [job.path, job.body]
    answer(201, { "token" => "t" })
    pump

    assert_equal [:post, "/memberships", { join_code: "2345678" }], [job.verb, job.path, job.body]
    assert_equal "t", @worker.started.first.last
  end

  def test_creating_posts_no_params
    @session.create
    pump
    answer(201, { "token" => "t" })
    pump

    assert_equal [:post, "/groups", nil], [job.verb, job.path, job.body]
  end

  def test_player_rate_limit_is_reported_and_blocks_the_next_try
    @session.join("2345678")
    pump
    answer(429, {}, retry_after: 30)

    assert_equal :too_many_tries, @session.error
    @session.create
    pump

    assert_equal :too_many_tries, @session.error
    assert_empty @worker.started
    @time += 31
    @session.create
    pump

    refute_empty @worker.started
  end

  def test_a_garbled_token_is_quietly_a_failure
    @session.join("2345678")
    pump
    answer(201, { "nope" => 1 })

    assert_equal :failed, @session.error
    assert_nil @session.token
  end

  { 404 => [{}, :no_such_group], 422 => [{}, :no_such_group], 400 => [{}, :no_such_group],
    409 => [{ "error" => "group_full" }, :group_full], 429 => [{}, :too_many_tries], 500 => [{}, :failed] }.each do |status, (body, reason)|
    define_method(:"test_joining_answered_#{status}_says_#{reason}") do
      @session.join("2345678")
      pump
      answer(201, { "token" => "t" })
      pump
      answer(status, body)

      assert_equal reason, @session.error
      refute_predicate @session, :member?
    end
  end

  %w[already_member group_limit].each do |error|
    define_method(:"test_joining_conflict_#{error}") do
      @session.join("2345678")
      pump
      answer(201, { "token" => "t" })
      pump
      answer(409, { "error" => error })

      assert_equal error.to_sym, @session.error
    end
  end

  def test_create_group_limit_and_an_unknown_conflict
    joined
    @session.create
    pump
    answer(409, { "error" => "group_limit" })

    assert_equal :group_limit, @session.error
    @session.create
    pump
    answer(409, { "error" => "whatever" })

    assert_equal :failed, @session.error
  end

  def test_join_retry_after_is_kept_within_bounds
    joined
    @session.join("1111111")
    pump
    answer(429, {}, retry_after: 99_999)
    @time += 3_601
    @session.create
    pump

    refute_empty @worker.started
  end

  def test_offline_is_reported_only_for_what_the_player_asked
    joined
    refreshed
    @session.refresh
    pump
    answer(0)

    assert_nil @session.error
    @session.create
    pump
    answer(0)

    assert_equal :offline, @session.error
  end

  def test_a_launch_with_no_known_groups_says_it_is_offline
    joined
    session = new_session
    @session = session
    session.refresh
    pump
    answer(0)

    assert_equal :offline, session.error
    assert_predicate session, :member?, "its games still count"
  end

  def test_a_bad_group_in_the_list_is_dropped_and_the_rest_kept
    joined
    refreshed([group, { "id" => "bad id" }, 7])

    assert_equal [1], @session.groups.map(&:id)
  end

  def test_a_body_of_the_wrong_kind_is_ignored
    joined
    @session.refresh
    pump
    answer(200, { "nope" => true })

    assert_equal [1], @session.groups.map(&:id)
    @session.look_at(1)
    pump
    answer(200, "garbage")
    answer(200, "garbage")

    assert_equal [1], @session.groups.map(&:id)
    assert_empty @session.title_changes(1)
  end

  def test_a_non_group_join_reply_is_a_failure
    @session.join("2345678")
    pump
    answer(201, { "token" => "t" })
    pump
    answer(201, { "id" => 1 })

    assert_equal :failed, @session.error
  end

  def test_group_404_drops_it
    joined
    @session.look_at(1)
    pump
    answer(404)

    refute_predicate @session, :member?
  end

  def test_title_changes_404_drops_it
    joined
    @session.look_at(1)
    pump
    answer(200, group)
    pump
    answer(404)

    assert_nil @session.group(1)
  end

  def test_group_5xx_changes_nothing
    joined
    @session.look_at(1)
    pump
    answer(503)
    answer(503)

    assert @session.group(1)
    assert_nil @session.error
  end

  def test_leaving_204_and_404_both_remove_the_group
    joined
    @session.leave(1)
    pump

    assert_equal [:delete, "/groups/1/membership"], [job.verb, job.path]
    answer(204)

    assert_nil @session.group(1)
    refute_predicate @session, :member?
    joined(group(id: 2))
    @session.leave(2)
    pump
    answer(404)

    assert_nil @session.group(2)
  end

  def test_leaving_keeps_other_groups_and_a_5xx_keeps_it
    joined
    refreshed([group, group(id: 2)], changes: [])
    @session.leave(1)
    pump
    answer(500)

    assert_equal :failed, @session.error
    assert @session.group(1)
    @session.leave(1)
    pump
    answer(204)

    assert_equal [2], @session.groups.map(&:id)
    assert_predicate @session, :member?
  end

  def test_delete_forgets_everything
    joined
    @session.delete_everything
    pump

    assert_equal [:delete, "/player"], [job.verb, job.path]
    answer(204)
    assert_nil @session.token
    refute_predicate new_session, :member?
    assert_empty @session.groups
  end

  def test_delete_404_also_forgets
    joined
    @session.delete_everything
    pump
    answer(404)

    assert_nil @session.token
  end

  def test_a_401_forgets_the_player
    joined
    @session.refresh
    pump
    answer(401)

    assert_nil @session.token
    refute_predicate @session, :member?
  end

  def test_nothing_is_sent_during_a_game
    joined
    @session.refresh
    @session.update(quiet: false)

    assert_empty @worker.started
  end

  def test_only_a_game_that_counts_is_sent
    joined
    @session.game_finished(score: 10, sized_to_screen: false)
    @session.game_finished(score: 0, sized_to_screen: true)
    pump

    assert_empty @worker.started
  end

  def test_a_non_member_reports_nothing
    @session.game_finished(score: 10, sized_to_screen: true)
    pump

    assert_empty @worker.started
  end

  def test_a_game_goes_to_the_server_and_a_win_is_told_in_the_result
    joined
    played(score: 60)

    assert_equal [:post, "/games", { score: 60 }], [job.verb, job.path, job.body]
    answer(200, { "groups" => [{ "group" => group(top: 60, champion: 2), "won_title" => true }] })

    assert_equal 1, @session.game_result.won
    assert_equal 60, @session.group(1).top_score
  end

  def test_the_score_is_capped
    joined
    played(score: 999_999)

    assert_equal 100_000, job.body[:score]
  end

  def test_a_champions_own_higher_score_raises_the_bar
    joined(group(champion: 2))
    played(score: 70)
    answer(200, { "groups" => [{ "group" => group(champion: 2, top: 70), "won_title" => false }] })

    assert_equal 0, @session.game_result.won
    assert_equal 1, @session.game_result.raised
  end

  def test_the_nearest_miss_is_kept_when_nothing_is_won
    joined
    refreshed([group, group(id: 2, top: 90)], changes: [])
    played(score: 40)
    answer(200, { "groups" => [{ "group" => group(top: 50), "won_title" => false },
                               { "group" => group(id: 2, top: 90), "won_title" => false }] })

    assert_equal 11, @session.game_result.short, "the score that wins must be strictly higher"
  end

  def test_a_champion_of_every_group_keeps_it
    joined(group(champion: 2, top: 90))
    played(score: 10)
    answer(200, { "groups" => [{ "group" => group(champion: 2, top: 90), "won_title" => false }] })

    assert_predicate @session.game_result, :reigning
  end

  def test_a_game_with_no_group_in_its_reply_is_not_a_crash
    joined
    played
    answer(200, "garbage")

    refute @session.game_result.won.positive?
  end

  def test_a_game_held_while_offline_waits_and_keeps_only_the_highest
    joined
    played(score: 30)
    answer(0)
    played(score: 20)
    answer(0)

    @session = new_session
    refreshed

    assert_equal({ score: 30 }, job.body)
  end

  [400, 404, 422].each do |status|
    define_method(:"test_a_game_answered_#{status}_is_dropped") do
      joined
      played
      answer(status)
      @session = new_session
      refreshed

      assert_empty paths
    end
  end

  [429, 500, 503].each do |status|
    define_method(:"test_a_game_answered_#{status}_waits") do
      joined
      played
      answer(status, {}, retry_after: 1)
      @time += 5
      refreshed

      assert_equal "/games", job.path
    end
  end

  def test_a_game_in_flight_is_not_sent_twice
    joined
    played(score: 30)
    refreshed
    played(score: 25)

    assert_equal ["/games"], paths.uniq.select { it == "/games" }
    assert_equal 1, paths.count("/games")
  end

  def test_leaving_the_last_group_drops_a_waiting_game
    joined
    played(score: 30)
    answer(0)
    @session.leave(1)
    pump
    answer(204)
    joined(group(id: 2))

    assert_empty paths
  end

  def test_a_lost_reply_is_learned_from_the_history
    joined
    played(score: 60)
    answer(0)
    @session.refresh
    pump
    answer(200, [group(champion: 2, top: 60)])
    pump

    assert_includes paths, "/groups/1/history"
    pending = paths
    answer(200, { "groups" => [{ "group" => group(champion: 2, top: 60), "won_title" => false }] }) if pending.first == "/games"
    pump
    answer(200, [change(5, champion: 2, previous: 1, score: 60)])

    assert_equal :you_won, @session.next_announcement.kind
  end

  def test_the_history_is_read_only_when_the_title_has_moved
    joined
    refreshed

    assert_empty paths
    refreshed([group(top: 80)])

    assert_includes paths, "/groups/1/history"
  end

  def test_a_new_change_is_announced_once_and_the_last_shown_is_remembered
    joined(changes: [change(4)])
    refreshed([group(top: 80, champion: 1)], changes: [change(9, previous: 2, score: 80), change(4)])

    assert_equal :you_lost, @session.next_announcement.kind
    assert_nil @session.next_announcement
    @session = new_session
    refreshed([group(top: 80, champion: 1)])

    assert_empty paths, "nothing new to fetch after a restart"
    refreshed([group(top: 95, champion: 1)], changes: [change(9, previous: 2, score: 80), change(4)])

    assert_nil @session.next_announcement
  end

  def test_a_new_group_announces_nothing_from_its_past
    joined(changes: [change(9), change(4)])

    assert_nil @session.next_announcement
  end

  def test_only_the_newest_change_is_announced_per_group
    joined
    refreshed([group(top: 99)], changes: [change(9, champion: 1, previous: 2, score: 99), change(8, champion: 2, previous: 1, score: 70)])

    assert_equal 99, @session.next_announcement.score
    assert_nil @session.next_announcement
  end

  def test_a_title_change_among_others_is_changed
    joined
    refreshed([group(top: 60, you: 5, numbers: [5])], changes: [change(2, champion: 7, previous: 1, score: 60)])

    assert_equal :changed, @session.next_announcement.kind
  end

  def test_a_title_passed_on_is_announced_as_a_pass_and_a_win_or_a_missing_word_as_today
    joined
    refreshed([group(top: 60, champion: 2)], changes: [change(3, champion: 2, previous: 1, score: 60, passed_on: true)])

    assert_equal :passed_to_you, @session.next_announcement.kind
    refreshed([group(top: 70, champion: 1)], changes: [change(4, champion: 1, previous: 3, score: 70, passed_on: true), change(3)])

    assert_equal :passed, @session.next_announcement.kind
    refreshed([group(top: 80, champion: 2)], changes: [change(5, champion: 2, previous: 1, score: 80, passed_on: false), change(4)])

    assert_equal :you_won, @session.next_announcement.kind
    refreshed([group(top: 90, champion: 1)], changes: [change(6, champion: 1, previous: 2, score: 90), change(5)])

    assert_equal :you_lost, @session.next_announcement.kind
  end

  def test_history_keeps_newest_first_and_look_at_refetches
    joined
    @session.look_at(1)
    pump
    answer(200, group)
    pump
    answer(200, [change(2), change(9)])

    assert_equal [9, 2], @session.title_changes(1).map(&:id)
  end

  def test_no_server_means_no_groups
    refute_predicate Groups::Session.at(nil, store: @store), :available?
  end

  def test_session_off_offers_nothing
    off = Groups::Session.off

    refute_predicate off, :available?
    off.refresh
    off.update(quiet: true)
  end
end

class SessionHistoryTest < Minitest::Test
  def test_achievement_keys_fit_what_the_server_accepts
    DotPopper::Achievement::IDS.each { assert_match(/\A[a-z0-9][a-z0-9_.-]{0,63}\z/, it.to_s) }
  end
end
