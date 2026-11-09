# frozen_string_literal: true

require_relative "test_helper"

class EntitlementTest < Minitest::Test
  Entitlement = DotPopper::Entitlement

  def test_a_new_player_is_free_until_the_purchase_and_stays_pro
    store = DotPopper::ScoreRecord::Memory.new
    refute_predicate Entitlement.new(store), :pro?

    Entitlement.new(store).unlock!

    assert_predicate Entitlement.new(store), :pro?
  end

  def test_the_setting_stands_in_for_a_purchase
    assert Entitlement.forced?({ "DOT_POPPER_PRO" => "1" })
    refute Entitlement.forced?({})
    assert_predicate Entitlement.new(DotPopper::ScoreRecord::Memory.new, forced: true), :pro?
  end
end
