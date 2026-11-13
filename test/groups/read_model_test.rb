# frozen_string_literal: true

require "test_helper"

# What the game last heard from the server, and the rules for telling the
# player of a title change.
class ReadModelTest < Minitest::Test
  Groups = DotPopper::Groups

  def setup = @read = Groups::ReadModel.new

  def group(id: 1, you: 2, champion: 1, top: 50)
    Groups::Group.parse({ "id" => id, "join_code" => "2345678", "you" => you, "champion_number" => champion, "top_score" => top,
                          "members" => [{ "number" => 1, "top_score" => 10 }, { "number" => 2, "top_score" => 20 }] })
  end

  def change(id, champion: 1, previous: 2, score: 50) = { "id" => id, "champion_number" => champion, "previous_champion_number" => previous, "score" => score }

  def announcements = [].tap { |all| while (one = @read.next_announcement) do all << one end }

  def test_the_last_known_answer_stands_until_groups_are_heard
    assert_predicate Groups::ReadModel.new(last_known_member: true), :member?
    refute_predicate @read, :member?
    @read.upsert(group)

    assert_predicate @read, :member?
  end

  def test_what_the_server_answers_replaces_what_is_here
    @read.upsert(group)
    @read.upsert(group(top: 70))
    @read.upsert(group(id: 2))

    assert_equal [[1, 70], [2, 50]], @read.groups.map { [it.id, it.top_score] }
    @read.replace([group(id: 2)])

    assert_equal [2], @read.groups.map(&:id)
  end

  def test_a_group_listed_no_more_is_forgotten_with_what_was_seen_of_it
    @read.upsert(group)
    @read.read_history(1, [change(4)])
    @read.replace([])

    assert_empty @read.seen
  end

  def test_a_gone_group_takes_its_history_with_it
    @read.upsert(group)
    @read.read_history(1, [change(4)])
    @read.gone(1)

    assert_nil @read.group(1)
    assert_nil @read.title_changes(1)
    assert_nil @read.history(1)
    assert_empty @read.seen
  end

  def test_membership_is_remembered_and_its_change_told
    @read.upsert(group)

    assert @read.remember_membership
    refute @read.remember_membership
    @read.gone(1)

    assert @read.remember_membership
    refute @read.last_known_member
  end

  def test_the_history_is_worth_reading_only_once_the_title_has_moved
    @read.upsert(group)

    assert @read.title_moved?(group), "never read"
    @read.read_history(1, [])

    refute @read.title_moved?(group)
    assert @read.title_moved?(group(top: 60))
  end

  def test_a_history_is_taken_only_for_a_known_group_and_only_as_a_list
    refute @read.read_history(1, [change(4)])
    @read.upsert(group)

    refute @read.read_history(1, "garbage")
    assert @read.read_history(1, [change(2), change(9), { "kind" => "achievement", "id" => 5, "member_number" => 1, "key" => "steady" }])
    assert_equal [9, 2], @read.title_changes(1).map(&:id)
    assert_equal [9, 5, 2], @read.history(1).map(&:id)
  end

  def test_a_group_met_for_the_first_time_announces_nothing_of_its_past
    @read.upsert(group)
    @read.read_history(1, [change(9), change(4)])

    assert_empty announcements
  end

  def test_only_the_newest_change_not_yet_told_is_announced_once
    @read.upsert(group)
    @read.read_history(1, [change(4)])
    @read.read_history(1, [change(9, score: 90), change(8, score: 80), change(4)])

    assert_equal [90], announcements.map(&:score)
    @read.read_history(1, [change(9, score: 90), change(8, score: 80), change(4)])

    assert_empty announcements
  end

  def test_a_later_change_replaces_one_not_yet_told
    @read.upsert(group)
    @read.read_history(1, [change(4)])
    @read.read_history(1, [change(5, score: 60), change(4)])
    @read.read_history(1, [change(6, score: 70), change(5), change(4)])

    assert_equal [70], announcements.map(&:score)
  end

  def test_what_was_seen_is_kept_for_the_next_launch
    @read.upsert(group)
    @read.read_history(1, [change(4)])

    assert_equal({ 1 => Groups::Seen.new(last: 4, fingerprint: "1~50") }, @read.seen)
    later = Groups::ReadModel.new(seen: @read.seen)
    later.upsert(group)
    later.read_history(1, [change(4)])

    assert_empty [later.next_announcement].compact
  end

  def test_an_arrival_is_taken_once
    @read.arrived(3)

    assert_equal 3, @read.take_arrival
    assert_nil @read.take_arrival
  end

  def test_a_forgotten_player_has_heard_nothing
    @read.upsert(group)
    @read.read_history(1, [change(4)])
    @read.read_history(1, [change(5), change(4)])
    @read.forget

    assert_empty @read.groups
    assert_empty @read.seen
    assert_nil @read.next_announcement
    refute_predicate @read, :member?
  end
end
