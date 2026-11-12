# frozen_string_literal: true

require_relative "test_helper"

# Pro comes only from proof checked offline, never from a stored flag
# (ADR-0010).
class EntitlementTest < Minitest::Test
  Entitlement = DotPopper::Entitlement
  Receipt = DotPopper::Receipt

  def test_a_new_player_is_free_until_a_receipt_verifies
    entitlement = Entitlement.test
    refute_predicate entitlement, :pro?

    assert entitlement.prove(Receipt.issue)
    assert_predicate entitlement, :pro?
  end

  def test_nothing_is_kept_so_each_launch_asks_the_store_again
    Entitlement.test.prove(Receipt.issue)

    refute_predicate Entitlement.test, :pro?
  end

  # "What if that player just edits the text file to say 4? Silly."
  def test_text_a_player_could_write_is_never_proof
    entitlement = Entitlement.test
    ["pro", "4", "owned", "1", "", nil, "play:", "play:cHJv:cHJv", "apple:a.b.c", "apple:#{"A" * 400}"].each do |text|
      refute entitlement.prove(text), text.inspect
    end
    refute_predicate entitlement, :pro?
  end

  def test_a_refused_receipt_does_not_stop_a_good_one
    entitlement = Entitlement.test
    refute entitlement.prove("pro")
    refute entitlement.prove("pro")

    assert entitlement.prove(Receipt.issue)
  end

  def test_a_test_receipt_proves_nothing_in_a_store_build
    refute Entitlement.free.prove(Receipt.issue)
    refute_predicate Entitlement.free, :pro?
  end

  def test_a_license_key_that_verifies_is_pro
    assert_predicate Entitlement.new(license: Struct.new(:pro?).new(true)), :pro?
    refute_predicate Entitlement.new(license: Struct.new(:pro?).new(false)), :pro?
  end

  def test_the_setting_stands_in_for_a_purchase
    assert Entitlement.forced?({ "DOT_POPPER_PRO" => "1" })
    refute Entitlement.forced?({})
    assert_predicate Entitlement.new(forced: true), :pro?
  end
end
