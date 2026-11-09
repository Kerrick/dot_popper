# frozen_string_literal: true

require_relative "test_helper"

class FreeGamesTest < Minitest::Test
  FreeGames = DotPopper::FreeGames
  Memory = DotPopper::ScoreRecord::Memory

  def setup
    @store = Memory.new
    @day = Date.new(2026, 11, 8)
    @entitlement = DotPopper::Entitlement.new(Memory.new)
  end

  def games(metered: true, **) = FreeGames.new(@store, today: -> { @day }, entitlement: @entitlement, metered:, **)

  def test_a_fresh_save_holds_the_whole_bank_and_the_days_games
    games = games()

    assert_equal FreeGames::DAILY, games.daily_left
    assert_equal FreeGames::BANK, games.bank_left
    assert_equal FreeGames::DAILY + FreeGames::BANK, games.left
    assert_predicate games, :can_play?
  end

  def test_the_days_games_are_spent_before_the_bank
    games = games()
    FreeGames::DAILY.times { assert games.spend! }

    assert_equal 0, games.daily_left
    assert_equal FreeGames::BANK, games.bank_left
    assert games.spend!
    assert_equal FreeGames::BANK - 1, games.bank_left
  end

  def test_the_days_games_return_tomorrow_and_do_not_carry_over
    games = games()
    games.spend!
    @day += 1

    assert_equal FreeGames::DAILY, games.daily_left
    assert_equal FreeGames::BANK, games.bank_left
  end

  def test_unspent_daily_games_never_join_the_bank
    games = games()
    @day += 5

    assert_equal FreeGames::DAILY + FreeGames::BANK, games.left
  end

  def test_the_bank_never_refills
    games = games()
    (FreeGames::DAILY + FreeGames::BANK).times { assert games.spend! }
    @day += 1
    FreeGames::DAILY.times { assert games.spend! }
    @day += 1

    assert_equal 0, games.bank_left
    assert_equal FreeGames::DAILY, games.left
  end

  def test_out_of_games_refuses_until_the_next_day
    games = games(bank: 0)
    FreeGames::DAILY.times { games.spend! }

    refute_predicate games, :can_play?
    refute games.spend!
    assert_equal 0, games.left
    @day += 1

    assert games.spend!
  end

  def test_the_count_is_kept_in_the_save
    games = games()
    (FreeGames::DAILY + 2).times { games.spend! }
    again = games()

    assert_equal 0, again.daily_left
    assert_equal FreeGames::BANK - 2, again.bank_left
  end

  def test_a_day_rolled_over_in_the_save_starts_the_day_afresh
    games().spend!
    @day += 1

    assert_equal FreeGames::DAILY, games().daily_left
  end

  def test_a_save_that_is_not_readable_is_a_fresh_one
    @store.write("day=never\nspent=-3\nbank=lots\n")

    assert_equal FreeGames::DAILY + FreeGames::BANK, games().left
  end

  def test_the_pro_version_counts_nothing_and_never_refuses
    @entitlement.unlock!
    games = games(bank: 0, daily: 0)

    assert_predicate games, :can_play?
    refute_predicate games, :metered?
    assert games.spend!
    assert_nil @store.read
  end

  def test_buying_part_way_stops_the_counting_and_keeps_what_was_left
    games = games()
    (FreeGames::DAILY + 1).times { games.spend! }
    @entitlement.unlock!

    10.times { assert games.spend! }
    assert_equal FreeGames::BANK - 1, games.bank_left
  end

  def test_buying_when_out_of_games_lets_play_go_on
    games = games(bank: 0)
    FreeGames::DAILY.times { games.spend! }
    @entitlement.unlock!

    assert_predicate games, :can_play?
  end

  def test_forcing_the_pro_version_counts_nothing
    forced = DotPopper::Entitlement.new(Memory.new, forced: true)
    games = FreeGames.new(@store, today: -> { @day }, entitlement: forced)

    5.times { assert games.spend! }
    assert_nil @store.read
  end

  def test_a_build_that_cannot_sell_is_not_metered
    games = games(metered: false, bank: 0, daily: 0)

    assert_predicate games, :can_play?
    assert games.spend!
    refute_predicate FreeGames.unlimited, :metered?
  end
end
