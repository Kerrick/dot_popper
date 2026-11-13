# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Joining or creating a friend group is Pro's: a Free player is offered
# Pro, and nothing is sent.
class JoinOrCreateFriendGroupTest < Minitest::Test
  # The friend-group session as a local fake: what it was asked.
  class Groups
    attr_reader :asked

    def initialize = @asked = []
    def create = @asked << :create
    def join(code) = @asked << [:join, code]
  end

  def setup = @groups = Groups.new

  def joining(pro:) = DotPopper::UseCases::JoinOrCreateFriendGroup.new(groups: @groups, entitlement: DotPopper::Entitlement.new(forced: pro))

  def test_pro_creates_and_joins
    pro = joining(pro: true)

    refute_predicate pro, :locked?
    assert_equal :go, pro.start
    assert_equal :sent, pro.create
    assert_equal :sent, pro.join("2345678")
    assert_equal [:create, [:join, "2345678"]], @groups.asked
  end

  def test_a_free_player_is_offered_pro_and_nothing_is_sent
    free = joining(pro: false)

    assert_predicate free, :locked?
    assert_equal :offer, free.start
    assert_equal :offer, free.create
    assert_equal :offer, free.join("2345678")
    assert_empty @groups.asked
  end
end
