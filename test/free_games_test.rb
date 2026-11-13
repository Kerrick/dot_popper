# frozen_string_literal: true

require_relative "test_helper"

class FreeGamesTest < Minitest::Test
  FreeGames = DotPopper::FreeGames
  Memory = DotPopper::ScoreRecord::Memory

  def setup
    @store = Memory.new
    @day = Date.new(2026, 11, 8)
    @entitlement = DotPopper::Entitlement.test
  end

  def games(metered: true, **) = FreeGames.new(@store, today: -> { @day }, entitlement: @entitlement, metered:, **)

  def test_a_fresh_save_holds_every_first_game_and_the_days_games
    games = games()

    assert_equal FreeGames::DAILY, games.daily_left
    assert_equal FreeGames::FIRST_GAMES, games.first_games_left
    assert_equal FreeGames::DAILY + FreeGames::FIRST_GAMES, games.left
    assert_predicate games, :can_play?
  end

  def test_the_days_games_are_spent_before_the_first_games
    games = games()
    FreeGames::DAILY.times { assert games.spend! }

    assert_equal 0, games.daily_left
    assert_equal FreeGames::FIRST_GAMES, games.first_games_left
    assert games.spend!
    assert_equal FreeGames::FIRST_GAMES - 1, games.first_games_left
  end

  def test_the_days_games_return_tomorrow_and_do_not_carry_over
    games = games()
    games.spend!
    @day += 1

    assert_equal FreeGames::DAILY, games.daily_left
    assert_equal FreeGames::FIRST_GAMES, games.first_games_left
  end

  def test_unspent_daily_games_never_join_the_first_games
    games = games()
    @day += 5

    assert_equal FreeGames::DAILY + FreeGames::FIRST_GAMES, games.left
  end

  def test_the_first_games_never_refill
    games = games()
    (FreeGames::DAILY + FreeGames::FIRST_GAMES).times { assert games.spend! }
    @day += 1
    FreeGames::DAILY.times { assert games.spend! }
    @day += 1

    assert_equal 0, games.first_games_left
    assert_equal FreeGames::DAILY, games.left
  end

  def test_out_of_games_refuses_until_the_next_day
    games = games(first_games: 0)
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
    assert_equal FreeGames::FIRST_GAMES - 2, again.first_games_left
  end

  def test_the_save_counts_the_first_games_used
    (FreeGames::DAILY + 2).times { games().spend! }

    assert_equal "day=2026-11-08\nspent=#{FreeGames::DAILY}\nfirst_games_used=2\n", @store.read
  end

  # Before the save counted the first games used, it kept those left.
  def test_an_earlier_save_of_the_first_games_left_carries_over
    @store.write("day=2026-11-08\nspent=1\nbank=17\n")
    games = games()

    assert_equal 17, games.first_games_left
    assert_equal FreeGames::DAILY - 1, games.daily_left
    FreeGames::DAILY.times { games.spend! }

    assert_equal 16, games().first_games_left
    assert_includes @store.read, "first_games_used=4"
    refute_includes @store.read, "bank"
  end

  def test_an_earlier_save_with_more_left_than_the_first_games_has_used_none
    @store.write("bank=#{FreeGames::FIRST_GAMES + 5}\n")

    assert_equal FreeGames::FIRST_GAMES, games().first_games_left
  end

  def test_more_used_than_the_first_games_leaves_none
    @store.write("first_games_used=#{FreeGames::FIRST_GAMES + 5}\n")

    assert_equal 0, games().first_games_left
  end

  def test_a_day_rolled_over_in_the_save_starts_the_day_afresh
    games().spend!
    @day += 1

    assert_equal FreeGames::DAILY, games().daily_left
  end

  def test_a_save_that_is_not_readable_is_a_fresh_one
    @store.write("day=never\nspent=-3\nbank=lots\nfirst_games_used=-1\n")

    assert_equal FreeGames::DAILY + FreeGames::FIRST_GAMES, games().left
  end

  def test_the_pro_version_counts_nothing_and_never_refuses
    @entitlement.prove(DotPopper::Receipt.issue)
    games = games(first_games: 0, daily: 0)

    assert_predicate games, :can_play?
    refute_predicate games, :metered?
    assert games.spend!
    assert_nil @store.read
  end

  def test_buying_part_way_stops_the_counting_and_keeps_what_was_left
    games = games()
    (FreeGames::DAILY + 1).times { games.spend! }
    @entitlement.prove(DotPopper::Receipt.issue)

    10.times { assert games.spend! }
    assert_equal FreeGames::FIRST_GAMES - 1, games.first_games_left
  end

  def test_buying_when_out_of_games_lets_play_go_on
    games = games(first_games: 0)
    FreeGames::DAILY.times { games.spend! }
    @entitlement.prove(DotPopper::Receipt.issue)

    assert_predicate games, :can_play?
  end

  def test_forcing_the_pro_version_counts_nothing
    forced = DotPopper::Entitlement.new(forced: true)
    games = FreeGames.new(@store, today: -> { @day }, entitlement: forced)

    5.times { assert games.spend! }
    assert_nil @store.read
  end

  def test_a_build_that_cannot_sell_is_not_metered
    games = games(metered: false, first_games: 0, daily: 0)

    assert_predicate games, :can_play?
    assert games.spend!
    refute_predicate FreeGames.unlimited, :metered?
  end

  # Who is counted (ADR-0012): a player, not the autoplay bot nor a GUI
  # scenario unless it sets DOT_POPPER_FREE_GAMES to try the limit; and in
  # a store build everyone, whatever its settings say.
  def test_a_store_build_counts_free_games_even_for_a_bot_or_a_scenario
    bot = { "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SCENARIO" => "game" }

    assert FreeGames.player?(bot, channel: DotPopper::Build::WEBSITE)
    refute FreeGames.player?(bot, channel: nil)
    refute FreeGames.player?({ "DOT_POPPER_AUTOPLAY" => "1" }, channel: nil)
    refute FreeGames.player?({ "DOT_POPPER_SCENARIO" => "game" }, channel: nil)
    assert FreeGames.player?({ "DOT_POPPER_SCENARIO" => "game", "DOT_POPPER_FREE_GAMES" => "2" }, channel: nil)
    assert FreeGames.player?({}, channel: nil)
  end

  # Counted only where Pro can be bought, since a limit with no way past it
  # is a dead end.
  def test_free_games_are_counted_only_where_pro_is_offered
    assert FreeGames.metered?({}, channel: DotPopper::Build::WEBSITE, offered: true)
    refute FreeGames.metered?({}, channel: DotPopper::Build::WEBSITE, offered: false)
    refute FreeGames.metered?({ "DOT_POPPER_AUTOPLAY" => "1" }, channel: nil, offered: true)
  end

  def test_a_new_save_can_start_with_the_games_a_developer_asks_for
    assert_equal 2, FreeGames.starting({ "DOT_POPPER_FREE_GAMES" => "2" })
    assert_nil FreeGames.starting({ "DOT_POPPER_FREE_GAMES" => "lots" })
    assert_nil FreeGames.starting({})
  end
end
