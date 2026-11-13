# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Buying Pro: the offer's actions reach the store only while they mean
# something, the store is heard only outside a game, and friend groups
# hear of what was earned while Free once Pro arrives.
class BuyProTest < Minitest::Test
  include DotPopperTest

  # The store port's answers, as a local fake: what it was asked.
  class Store
    attr_accessor :price, :sold
    attr_reader :asked

    def initialize = (@asked = []) && (@sold = true)

    def offered? = true
    def status = :ready
    def sold? = sold
    def connect = @asked << :connect
    def buy = @asked << :buy
    def restore = @asked << :restore
    def paste = @asked << :paste
    def type(key) = (@asked << [:type, key]) && true
    def update(seconds) = @asked << [:update, seconds]
  end

  class Groups
    attr_reader :reported

    def initialize = @reported = []
    def report_achievements(ids) = @reported << ids
  end

  def setup
    @store = Store.new
    @entitlement = DotPopper::Entitlement.test
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(1))
    @achievements = DotPopper::Achievements.new(DotPopper::ScoreRecord::Memory.new)
    @groups = Groups.new
    @buy = DotPopper::UseCases::BuyPro.new(store: @store, entitlement: @entitlement, cabinet: @cabinet, achievements: @achievements,
                                           friend_groups: @groups)
    @entitlement.subscribe(@buy) # as the composition root subscribes it
  end

  def test_buy_with_a_price_buys_and_without_one_asks_again
    assert @buy.buy
    @store.price = "$1.99"
    assert @buy.buy

    assert_equal %i[connect buy], @store.asked
  end

  def test_the_offer_says_how_the_store_is_getting_on_until_the_player_has_pro
    assert_equal :ready, @buy.status
  end

  def test_nothing_is_bought_once_pro_or_where_pro_is_not_sold
    @store.sold = false
    refute @buy.buy
    @store.sold = true
    @entitlement.prove(DotPopper::Receipt.issue)

    refute @buy.buy
    refute @buy.type(:a)
    refute_predicate @buy, :offered?
    assert_equal :thanks, @buy.status
    assert_empty @store.asked
  end

  def test_the_store_is_heard_only_while_no_game_is_in_play
    @buy.update(0.25)
    start!(@cabinet)
    @buy.update(0.25)
    @cabinet.update(20)
    @buy.update(0.5)

    assert_equal [[:update, 0.25], [:update, 0.5]], @store.asked
  end

  def test_when_pro_arrives_friend_groups_hear_of_every_achievement_earned_while_free
    @achievements.award(%i[blink big_score], day: "2026-11-01")
    @entitlement.prove(DotPopper::Receipt.issue)

    assert_equal [%i[blink big_score]], @groups.reported
  end

  def test_a_license_key_entered_is_pro_arriving_too
    license = DotPopper::Continuity::License.new(DotPopper::ScoreRecord::Memory.new, pins: DotPopper::Continuity::TEST_PINS)
    entitlement = DotPopper::Entitlement.new(license:)
    entitlement.subscribe(DotPopper::UseCases::BuyPro.new(store: @store, entitlement:, cabinet: @cabinet, achievements: @achievements,
                                                          friend_groups: @groups))
    @achievements.award(%i[steady], day: "2026-11-01")
    entitlement.enter(DotPopper::Continuity::LicenseKey.issue(DotPopper::Continuity::TestKeys::LICENSE).text)

    assert_equal [%i[steady]], @groups.reported
  end

end
