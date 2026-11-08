# frozen_string_literal: true

require_relative "test_helper"

class EntitlementTest < Minitest::Test
  Entitlement = DotPopper::Entitlement

  def test_a_new_player_is_free_until_the_purchase_and_stays_paid
    store = DotPopper::BestScore::Memory.new
    refute_predicate Entitlement.new(store), :paid?

    Entitlement.new(store).unlock!

    assert_predicate Entitlement.new(store), :paid?
  end

  def test_the_setting_stands_in_for_a_purchase
    assert Entitlement.forced?({ "DOT_POPPER_PAID" => "1" })
    refute Entitlement.forced?({})
    assert_predicate Entitlement.new(DotPopper::BestScore::Memory.new, forced: true), :paid?
  end
end
