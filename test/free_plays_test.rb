# frozen_string_literal: true

require_relative "test_helper"

class FreePlaysTest < Minitest::Test
  FreePlays = DotPopper::FreePlays
  Memory = DotPopper::BestScore::Memory

  def setup
    @store = Memory.new
    @day = Date.new(2026, 11, 8)
    @entitlement = DotPopper::Entitlement.new(Memory.new)
  end

  def plays(metered: true, **) = FreePlays.new(@store, today: -> { @day }, entitlement: @entitlement, metered:, **)

  def test_a_fresh_save_holds_the_whole_bank_and_the_days_plays
    plays = plays()

    assert_equal FreePlays::DAILY, plays.daily_left
    assert_equal FreePlays::BANK, plays.bank_left
    assert_equal FreePlays::DAILY + FreePlays::BANK, plays.left
    assert_predicate plays, :can_play?
  end

  def test_the_days_plays_are_spent_before_the_bank
    plays = plays()
    FreePlays::DAILY.times { assert plays.spend! }

    assert_equal 0, plays.daily_left
    assert_equal FreePlays::BANK, plays.bank_left
    assert plays.spend!
    assert_equal FreePlays::BANK - 1, plays.bank_left
  end

  def test_the_days_plays_return_tomorrow_and_do_not_carry_over
    plays = plays()
    plays.spend!
    @day += 1

    assert_equal FreePlays::DAILY, plays.daily_left
    assert_equal FreePlays::BANK, plays.bank_left
  end

  def test_unspent_daily_plays_never_join_the_bank
    plays = plays()
    @day += 5

    assert_equal FreePlays::DAILY + FreePlays::BANK, plays.left
  end

  def test_the_bank_never_refills
    plays = plays()
    (FreePlays::DAILY + FreePlays::BANK).times { assert plays.spend! }
    @day += 1
    FreePlays::DAILY.times { assert plays.spend! }
    @day += 1

    assert_equal 0, plays.bank_left
    assert_equal FreePlays::DAILY, plays.left
  end

  def test_out_of_plays_refuses_until_the_next_day
    plays = plays(bank: 0)
    FreePlays::DAILY.times { plays.spend! }

    refute_predicate plays, :can_play?
    refute plays.spend!
    assert_equal 0, plays.left
    @day += 1

    assert plays.spend!
  end

  def test_the_count_is_kept_in_the_save
    plays = plays()
    (FreePlays::DAILY + 2).times { plays.spend! }
    again = plays()

    assert_equal 0, again.daily_left
    assert_equal FreePlays::BANK - 2, again.bank_left
  end

  def test_a_day_rolled_over_in_the_save_starts_the_day_afresh
    plays().spend!
    @day += 1

    assert_equal FreePlays::DAILY, plays().daily_left
  end

  def test_a_save_that_is_not_readable_is_a_fresh_one
    @store.write("day=never\nspent=-3\nbank=lots\n")

    assert_equal FreePlays::DAILY + FreePlays::BANK, plays().left
  end

  def test_the_paid_version_counts_nothing_and_never_refuses
    @entitlement.unlock!
    plays = plays(bank: 0, daily: 0)

    assert_predicate plays, :can_play?
    refute_predicate plays, :metered?
    assert plays.spend!
    assert_nil @store.read
  end

  def test_buying_part_way_stops_the_counting_and_keeps_what_was_left
    plays = plays()
    (FreePlays::DAILY + 1).times { plays.spend! }
    @entitlement.unlock!

    10.times { assert plays.spend! }
    assert_equal FreePlays::BANK - 1, plays.bank_left
  end

  def test_buying_when_out_of_plays_lets_play_go_on
    plays = plays(bank: 0)
    FreePlays::DAILY.times { plays.spend! }
    @entitlement.unlock!

    assert_predicate plays, :can_play?
  end

  def test_forcing_the_paid_version_counts_nothing
    forced = DotPopper::Entitlement.new(Memory.new, forced: true)
    plays = FreePlays.new(@store, today: -> { @day }, entitlement: forced)

    5.times { assert plays.spend! }
    assert_nil @store.read
  end

  def test_a_build_that_cannot_sell_is_not_metered
    plays = plays(metered: false, bank: 0, daily: 0)

    assert_predicate plays, :can_play?
    assert plays.spend!
    refute_predicate FreePlays.unlimited, :metered?
  end
end
