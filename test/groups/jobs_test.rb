# frozen_string_literal: true

require "test_helper"

# Each kind of request friend groups make: what it sends, from its
# declaration, and what each answer means.
class JobsTest < Minitest::Test
  Groups = DotPopper::Groups
  Jobs = Groups::Jobs
  Reply = DotPopper::Network::Reply

  # A session that writes down what a job's answers ask of it.
  class Heard
    attr_reader :calls

    def initialize = @calls = []

    %i[adopt read_groups read_group history_settled gone achievement_settled drop_achievement score_settled give_up_score
       forget_identity].each do |name|
      define_method(name) { |*args| @calls << [name, *args] }
    end

    def arrived(body, loud:) = @calls << [:arrived, body, loud]
    def read_history(id, body) = @calls << [:read_history, id, body]
    def achievement_taken(key, body) = @calls << [:achievement_taken, key, body]
    def game_taken(score, body) = @calls << [:game_taken, score, body]
  end

  def setup = @heard = Heard.new

  def reply(status, body = {}) = Reply.new(status:, body:)

  def every_kind
    [Jobs::NewPlayer.new(next_job: Jobs::CreateGroup.new), Jobs::ListGroups.new(loud: false), Jobs::CreateGroup.new,
     Jobs::JoinGroup.new("2345678"), Jobs::ReadGroup.new(3), Jobs::ReadHistory.new(3), Jobs::SendAchievement.new("steady"),
     Jobs::LeaveGroup.new(3), Jobs::SendGame.new(60), Jobs::DeletePlayer.new]
  end

  def test_there_is_one_kind_for_each_declaration
    assert_equal Groups::REQUESTS.keys.sort, every_kind.map(&:kind).sort
  end

  def test_each_sends_what_its_declaration_says
    every_kind.each do |job|
      request = Groups::REQUESTS.fetch(job.kind)

      assert_equal request.verb, job.verb
      assert_equal request.path.sub(":id", "3"), job.path
      assert_equal request.body.keys, job.body.to_h.keys
    end
  end

  def test_what_each_sends
    assert_equal({ join_code: "2345678" }, Jobs::JoinGroup.new("2345678").body)
    assert_equal({ key: "steady" }, Jobs::SendAchievement.new("steady").body)
    assert_equal({ score: 60 }, Jobs::SendGame.new(60).body)
    assert_nil Jobs::CreateGroup.new.body
  end

  def test_only_what_the_player_asked_for_is_loud
    loud = every_kind.select(&:loud?).map(&:kind)

    assert_equal %i[player create join left deleted], loud
    assert_predicate Jobs::ListGroups.new(loud: true), :loud?
  end

  def test_what_a_refusal_means_for_the_player
    join = Jobs::JoinGroup.new("2345678")

    assert_equal [:no_such_group, :no_such_group, :no_such_group, :too_many_tries, :failed], [400, 404, 422, 429, 500].map { join.reason(reply(it)) }
    assert_equal :too_many_tries, Jobs::NewPlayer.new(next_job: join).reason(reply(429))
    assert_equal :too_many_tries, Jobs::CreateGroup.new.reason(reply(429))
    assert_equal :failed, Jobs::LeaveGroup.new(3).reason(reply(429))
    assert_equal :group_full, Jobs::CreateGroup.new.reason(reply(409, { "error" => "group_full" }))
    assert_equal :failed, join.reason(reply(409, { "error" => "nonsense" }))
    assert_equal :failed, join.reason(reply(409, "a page"))
  end

  def test_what_each_does_with_an_answer_taken
    every_kind.each { it.taken(@heard, reply(200, "body")) }

    assert_equal [[:adopt, "body"], [:read_groups, "body"], [:arrived, "body", true], [:arrived, "body", true], [:read_group, "body"],
                  [:read_history, 3, "body"], [:achievement_taken, "steady", "body"], [:gone, 3], [:game_taken, 60, "body"], [:forget_identity]],
                 @heard.calls
  end

  def test_what_each_must_hear_of_however_it_went
    every_kind.each { it.settled(@heard) }

    assert_equal [[:history_settled, 3], [:achievement_settled, "steady"], [:score_settled]], @heard.calls
  end

  def test_a_group_no_longer_there_is_gone
    [Jobs::ReadGroup.new(3), Jobs::ReadHistory.new(3), Jobs::LeaveGroup.new(3)].each do |job|
      refute job.refused(@heard, reply(500))
      assert job.refused(@heard, reply(404))
    end

    assert_equal [[:gone, 3]] * 3, @heard.calls
  end

  def test_something_owed_the_server_will_never_take_is_owed_no_longer
    [400, 404, 422].each do |status|
      assert Jobs::SendGame.new(60).refused(@heard, reply(status))
      assert Jobs::SendAchievement.new("steady").refused(@heard, reply(status))
    end
    [429, 500, 503].each do |status|
      refute Jobs::SendGame.new(60).refused(@heard, reply(status))
      refute Jobs::SendAchievement.new("steady").refused(@heard, reply(status))
    end

    assert_equal [[:give_up_score], [:drop_achievement, "steady"]] * 3, @heard.calls
  end

  def test_a_player_the_server_does_not_know_is_as_good_as_deleted
    assert Jobs::DeletePlayer.new.refused(@heard, reply(404))
    refute Jobs::DeletePlayer.new.refused(@heard, reply(500))
    assert_equal [[:forget_identity]], @heard.calls
  end

  def test_other_refusals_are_left_to_the_session
    [Jobs::NewPlayer.new(next_job: Jobs::CreateGroup.new), Jobs::ListGroups.new(loud: true), Jobs::CreateGroup.new, Jobs::JoinGroup.new("1")].each do |job|
      [400, 404, 409, 422, 429, 500].each { refute job.refused(@heard, reply(it)) }
    end

    assert_empty @heard.calls
  end

  def test_a_new_player_comes_before_the_job_it_was_made_for
    create = Jobs::CreateGroup.new

    assert_same create, Jobs::NewPlayer.new(next_job: create).next_job
    assert_nil create.next_job
  end
end
