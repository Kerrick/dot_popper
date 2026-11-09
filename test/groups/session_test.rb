# frozen_string_literal: true

require "test_helper"

class SessionTest < Minitest::Test
  Groups = DotPopper::Groups
  Reply = Groups::Reply
  DAY = 86_400

  # A worker that holds each job until the test answers it.
  class HandWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  def setup
    @store = DotPopper::BestScore::Memory.new
    @worker = HandWorker.new
    @time = Time.at(DAY * 1000)
    @session = new_session
  end

  def new_session = Groups::Session.new(store: @store, worker: @worker, clock: -> { @time })
  def pump = @session.update(quiet: true)

  # A group as the server sends it: seats are 1 to 8, mine the first.
  def group(score: 5, seats: [5], holder: nil)
    { "join_code" => "2345678", "seat" => seats.first, "member_seats" => seats, "holder_seat" => holder,
      "score_to_beat" => score }
  end

  def answer(status, body, retry_after: nil)
    @worker.answer(Reply.new(status:, body:, retry_after:))
    pump
  end

  # Joins, and hears the group and that there are no thefts.
  def joined
    @session.join(4, "2345678")
    pump
    answer(201, { "token" => "t" })
    pump
    answer(201, group)
    pump
    answer(200, [])
  end

  # Refreshes the group and answers the request for thefts.
  def refreshed(group = group(), thefts: [])
    @session.refresh
    pump
    answer(200, group)
    pump
    answer(200, thefts)
  end

  def test_a_new_player_asks_nothing
    @session.refresh
    pump

    assert_empty @worker.started
  end

  def test_joining_becomes_a_player_first_and_remembers_them
    joined

    assert_predicate @session, :member?
    assert_equal 4, @session.mark
    assert_equal 4, new_session.mark
    assert_equal "t", new_session.token
  end

  def test_a_player_gives_the_server_only_a_token_and_a_seat
    @session.join(4, "2345678")
    pump

    job = @worker.started.first.first

    assert_equal [:player, :post, "/player", nil], [job.kind, job.verb, job.path, job.body]
    answer(201, { "token" => "t" })
    pump

    assert_equal([:post, "/membership", { join_code: "2345678", seat: 5 }],
                 [@worker.started.first.first.verb, @worker.started.first.first.path, @worker.started.first.first.body])
    refute_respond_to @session, :name
    refute_respond_to @session, :report
    refute_respond_to @session, :block
  end

  def test_the_server_may_give_another_seat_when_the_one_asked_for_is_taken
    joined
    refreshed(group(seats: [3, 5]))

    assert_equal 2, @session.mark, "seat 3 is the game's mark 2"
    assert_equal [[2, true], [4, false]], @session.members.map { [it.mark, it.you] }
  end

  def test_the_group_is_read_in_marks
    joined
    refreshed(group(seats: [2, 1, 8], holder: 8))

    assert_equal [0, 1, 7], @session.members.map(&:mark)
    assert_equal 7, @session.holder_mark
    assert_equal "2345678", @session.join_code
    refreshed(group(seats: [2]))

    assert_nil @session.holder_mark
  end

  def test_a_group_that_is_not_one_is_a_quiet_failure
    @session.join(4, "2345678")
    pump
    answer(201, { "token" => "t" })
    pump
    answer(201, group.merge("seat" => 9))

    assert_equal :failed, @session.error
    refute_predicate @session, :member?
  end

  def test_nothing_is_sent_while_a_round_is_in_play
    joined
    @session.refresh
    @session.update(quiet: false)

    assert_empty @worker.started
    pump
    assert_equal 1, @worker.started.size
  end

  def test_offline_is_quiet_and_keeps_what_it_knows
    joined
    @session.refresh
    pump
    @worker.answer(Reply.offline)
    pump

    assert_equal :offline, @session.error
    assert_predicate @session, :member?
  end

  def test_a_round_not_sized_to_the_screen_is_not_reported
    joined
    @session.round_finished(score: 10, sized_to_screen: false)
    pump

    assert_empty @worker.started
  end

  def test_an_unsent_round_is_kept_for_later
    joined
    @session.round_finished(score: 10, sized_to_screen: true)
    pump
    @worker.answer(Reply.offline)
    pump
    @session.refresh
    pump
    answer(200, group)

    assert_equal %i[thefts round], @worker.started.map { it.first.kind }
  end

  def test_an_unsent_round_too_old_is_dropped
    joined
    @session.round_finished(score: 10, sized_to_screen: true)
    pump
    @worker.answer(Reply.offline)
    pump
    @time += DAY * 3
    @session.refresh
    pump
    answer(200, group)

    assert_equal [:thefts], @worker.started.map { it.first.kind }
  end

  def test_a_round_after_a_launch_with_no_network_still_counts
    joined
    @session = new_session
    @session.round_finished(score: 10, sized_to_screen: true)
    pump

    assert_equal [:round], @worker.started.map { it.first.kind }
  end

  def test_a_waiting_round_is_dropped_if_the_player_has_left_the_group
    joined
    @session = new_session
    @session.round_finished(score: 10, sized_to_screen: true)
    pump
    answer(404, {})
    @session.round_finished(score: 11, sized_to_screen: true)
    pump

    assert_empty @worker.started
  end

  def test_a_round_that_takes_the_trophy_is_told_once
    joined
    @session.round_finished(score: 10, sized_to_screen: true)
    pump
    answer(200, { "took_trophy" => true, "group" => group(score: 10, holder: 5) })

    assert_equal [:taken, 10], @session.next_message.then { [it.kind, it.score] }
    assert_nil @session.next_message
  end

  def test_a_theft_is_told_once_even_across_launches
    joined
    news = [{ "id" => 9, "thief_seat" => 7, "score" => 12, "taken_at" => "2026-03-04T12:00:00.000Z" }]
    refreshed(thefts: news)

    assert_equal [6, 12], @session.next_message.then { [it.who, it.score] }

    @session = new_session
    @worker.started.clear
    refreshed(thefts: news)

    assert_nil @session.next_message
  end

  def test_an_unknown_token_forgets_this_player
    joined
    @session.refresh
    pump
    answer(401, {})

    refute_predicate @session, :known?
  end

  def test_deleting_forgets_everything_here
    joined
    @session.delete_everything
    pump
    answer(204, {})

    refute_predicate @session, :known?
    assert_nil new_session.token
  end

  def test_a_round_is_reported_as_a_score_in_range_and_nothing_else
    joined
    @session.round_finished(score: 250_000, sized_to_screen: true)
    pump

    job = @worker.started.first.first

    assert_equal [:post, "/group/rounds", { score: 100_000 }], [job.verb, job.path, job.body]
  end

  def test_a_creator_asks_for_the_seat_they_want_and_says_nothing_of_payment
    @session.create(3)
    pump
    answer(201, { "token" => "t" })
    pump
    job = @worker.started.first.first

    assert_equal [:post, "/group", { seat: 4 }], [job.verb, job.path, job.body]
    answer(201, group(seats: [6]))

    assert_equal 5, @session.mark, "the server gave the lowest free seat"
  end

  def test_a_told_theft_is_deleted_by_id_and_forgotten_once_gone
    joined
    news = [{ "id" => 9, "thief_seat" => 7, "score" => 12 }]
    refreshed(thefts: news)
    @session.next_message
    pump
    job = @worker.started.first.first

    assert_equal [:delete, "/group/thefts/9"], [job.verb, job.path]
    @worker.answer(Reply.offline)
    pump
    refreshed(thefts: news)

    assert_nil @session.next_message
    assert_equal [[:delete, "/group/thefts/9"]], @worker.started.map { [it.first.verb, it.first.path] }
    answer(204, nil)
    refreshed

    assert_nil @session.next_message
  end

  def test_each_refusal_status_says_what_went_wrong
    {
      [:create, 409, "group_full"] => :group_full, [:create, 409, "already_in_group"] => :already_in_group,
      [:create, 409, nil] => :failed, [:create, 422, nil] => :bad_mark, [:create, 429, nil] => :too_many_tries,
      [:create, 413, nil] => :failed, [:create, 500, nil] => :failed, [:create, 402, nil] => :failed,
      [:join, 400, nil] => :no_such_group, [:join, 404, nil] => :no_such_group,
      [:join, 409, "group_full"] => :group_full, [:join, 409, "already_in_group"] => :already_in_group,
      [:join, 422, nil] => :no_such_group, [:join, 429, nil] => :too_many_tries
    }.each do |(what, status, why), error|
      setup
      what == :create ? @session.create(1) : @session.join(1, "2345678")
      pump
      answer(201, { "token" => "t" })
      pump
      answer(status, why ? { "error" => why } : {})

      assert_equal error, @session.error, "#{what} #{status}"
      refute_predicate @session, :member?
    end
  end

  def test_a_422_on_the_seat_of_a_join_is_a_bad_dot_and_on_the_code_is_no_group
    @session.join(1, "2345678")
    pump
    answer(201, { "token" => "t" })
    pump
    answer(422, { "errors" => { "seat" => ["is invalid"] } })

    assert_equal :bad_mark, @session.error
  end

  def test_already_in_a_group_shows_that_group
    @session.create(1)
    pump
    answer(201, { "token" => "t" })
    pump
    answer(409, { "error" => "already_in_group" })

    assert_equal :already_in_group, @session.error
    assert_equal [:get, "/group"], @worker.started.map { [it.first.verb, it.first.path] }.first
  end

  def test_a_429_waits_out_its_retry_after_before_asking_again
    @session.create(1)
    pump
    answer(201, { "token" => "t" })
    pump
    answer(429, { "error" => "rate_limited" }, retry_after: 90)
    @session.create(1)
    pump

    assert_equal :too_many_tries, @session.error
    assert_empty @worker.started
    @time += 91
    @session.create(1)
    pump

    assert_equal [:post, "/group"], @worker.started.map { [it.first.verb, it.first.path] }.first
  end

  def test_a_429_that_names_a_huge_time_still_ends
    @session.create(1)
    pump
    answer(429, {}, retry_after: 10**9)
    @time += 3_601
    @session.create(1)
    pump

    refute_empty @worker.started
  end

  def test_no_group_is_not_an_error_when_asking_for_the_group_or_leaving
    joined
    @session.refresh
    pump
    answer(404, {})

    refute_predicate @session, :member?
    assert_nil @session.error
    @session.refresh
    pump
    answer(200, group)
    pump
    answer(200, [])
    @session.leave
    pump
    answer(404, {})

    refute_predicate @session, :member?
    assert_nil @session.error
  end

  def test_leaving_is_a_delete_of_the_membership
    joined
    @session.leave
    pump
    job = @worker.started.first.first

    assert_equal [:delete, "/membership"], [job.verb, job.path]
    answer(204, {})

    refute_predicate @session, :member?
  end

  def test_a_round_the_server_refuses_is_dropped_quietly
    joined
    @session.round_finished(score: 10, sized_to_screen: true)
    pump
    answer(422, {})

    assert_nil @session.error
    assert_predicate @session, :member?
    @session.refresh
    pump
    answer(200, group)

    assert_equal [:thefts], @worker.started.map { it.first.kind }
  end

  def test_a_failing_theft_delete_is_quiet
    joined
    refreshed(thefts: [{ "id" => 9, "thief_seat" => 7, "score" => 12 }])
    @session.next_message
    pump
    answer(404, {})

    assert_nil @session.error
  end

  def test_the_server_url_is_one_setting
    assert_nil Groups::Settings.server_url({})
    assert_equal Groups::Settings::TEST_SERVER_URL, Groups::Settings.server_url({}, test_build: true)
    assert_match(%r{\Ahttps://}, Groups::Settings::TEST_SERVER_URL)
    assert_equal "http://x:1", Groups::Settings.server_url({ "DOT_POPPER_SERVER" => "http://x:1" }, test_build: true)
    assert_nil Groups::Settings.server_url({ "DOT_POPPER_SERVER" => "" }, test_build: true)
    assert_nil Groups::Settings::SERVER_URL
    assert_equal "http://x:1", Groups::Settings.server_url({ "DOT_POPPER_SERVER" => "http://x:1" })
    refute_predicate Groups::Session.at(nil, store: @store), :available?
  end
end
