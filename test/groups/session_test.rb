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

  def group(score: 5, news: [], looks: [4])
    { "join_code" => "2345678", "holder_look" => nil, "score_to_beat" => score, "news" => news,
      "members" => looks.map { { "look" => it, "you" => it == looks.first } } }
  end

  def answer(status, body)
    @worker.answer(Reply.new(status:, body:))
    pump
  end

  def joined
    @session.join(4, "2345678")
    pump
    answer(201, { "token" => "t" })
    pump
    answer(201, group)
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

  def test_a_player_gives_the_server_only_a_token_and_a_mark
    @session.join(4, "2345678")
    pump

    job = @worker.started.first.first

    assert_equal [:player, :post, "/player", nil], [job.kind, job.verb, job.path, job.body]
    answer(201, { "token" => "t" })
    pump

    assert_equal([:post, "/membership", { join_code: "2345678", look: 4 }],
                 [@worker.started.first.first.verb, @worker.started.first.first.path, @worker.started.first.first.body])
    refute_respond_to @session, :name
    refute_respond_to @session, :report
    refute_respond_to @session, :block
  end

  def test_the_server_may_give_another_mark_when_the_one_asked_for_is_worn
    joined
    @session.refresh
    pump
    answer(200, group(looks: [2, 4]))

    assert_equal 2, @session.mark
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

    assert_equal [:round], @worker.started.map { it.first.kind }
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

    assert_empty @worker.started
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
    answer(200, { "took_trophy" => true, "group" => group(score: 10) })

    assert_equal [:taken, 10], @session.next_message.then { [it.kind, it.score] }
    assert_nil @session.next_message
  end

  def test_a_theft_is_told_once_even_across_launches
    joined
    news = [{ "id" => 9, "thief_look" => 6, "score" => 12 }]
    @session.refresh
    pump
    answer(200, group(news:))

    assert_equal [6, 12], @session.next_message.then { [it.who, it.score] }

    @session = new_session
    @worker.started.clear
    @session.refresh
    pump
    answer(200, group(news:))

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

  def test_a_round_is_reported_as_kind_one_with_a_score_in_range
    joined
    @session.round_finished(score: 250_000, sized_to_screen: true)
    pump

    job = @worker.started.first.first

    assert_equal [:post, "/group/rounds", { score: 100_000, kind: 1 }], [job.verb, job.path, job.body]
  end

  def test_a_creator_says_they_paid_with_the_look_they_want
    @session.create(3)
    pump
    answer(201, { "token" => "t" })
    pump
    job = @worker.started.first.first

    assert_equal [:post, "/group", { look: 3, paid: true }], [job.verb, job.path, job.body]
    answer(201, group(looks: [5]))

    assert_equal 5, @session.mark, "the server gave the lowest free look"
  end

  def test_a_told_theft_is_deleted_by_id_and_forgotten_once_gone
    joined
    news = [{ "id" => 9, "thief_look" => 6, "score" => 12 }]
    @session.refresh
    pump
    answer(200, group(news:))
    @session.next_message
    pump
    job = @worker.started.first.first

    assert_equal [:delete, "/group/news/9"], [job.verb, job.path]
    @worker.answer(Reply.offline)
    pump
    @session.refresh
    pump
    answer(200, group(news:))

    assert_nil @session.next_message
    assert_equal [[:delete, "/group/news/9"]], @worker.started.map { [it.first.verb, it.first.path] }
    answer(200, group)

    assert_nil @session.next_message
  end

  def test_each_refusal_status_says_what_went_wrong
    {
      [:create, 402] => :not_paid, [:create, 409] => :already_in_group, [:create, 422] => :bad_mark,
      [:create, 413] => :failed, [:create, 500] => :failed,
      [:join, 403] => :group_full, [:join, 404] => :no_such_group, [:join, 409] => :already_in_group,
      [:join, 422] => :no_such_group, [:join, 429] => :too_many_tries
    }.each do |(what, status), error|
      setup
      what == :create ? @session.create(1) : @session.join(1, "2345678")
      pump
      answer(201, { "token" => "t" })
      pump
      answer(status, {})

      assert_equal error, @session.error, "#{what} #{status}"
      refute_predicate @session, :member?
    end
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

    assert_empty @worker.started
  end

  def test_a_failing_theft_delete_is_quiet
    joined
    @session.refresh
    pump
    answer(200, group(news: [{ "id" => 9, "thief_look" => 6, "score" => 12 }]))
    @session.next_message
    pump
    answer(404, {})

    assert_nil @session.error
  end

  def test_the_server_url_is_one_setting
    assert_nil Groups::Settings.server_url({})
    assert_equal "http://x:1", Groups::Settings.server_url({ "DOT_POPPER_SERVER" => "http://x:1" })
    refute_predicate Groups::Session.at(nil, store: @store), :available?
  end
end
