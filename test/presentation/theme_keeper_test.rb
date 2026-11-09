# frozen_string_literal: true

require_relative "presentation_helper"

class ThemeKeeperTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory
  THEMES = Style::THEMES

  def setup
    @store = Memory.new
    @paid = Memory.new
    @day = Date.new(2026, 10, 31)
  end

  def test_a_free_player_always_wears_the_ordinary_style_even_in_season
    theme_keeper = theme_keeper(paid: false)

    assert_predicate theme_keeper.worn, :ordinary?
    assert_predicate theme_keeper, :offered?, "a free player is shown the looks"
    assert_predicate theme_keeper, :locked?
    assert_equal Style::THEMES, theme_keeper.shown
    theme_keeper.wear(Style::THEMES.last)

    assert_predicate theme_keeper.worn, :ordinary?
  end

  def test_a_paid_player_wears_the_theme_in_season_and_the_ordinary_style_out_of_it
    assert_equal :halloween, theme_keeper.worn.key
    @day = Date.new(2026, 11, 8)

    assert_predicate theme_keeper.worn, :ordinary?
  end

  def test_one_game_in_season_earns_a_theme_for_good
    theme_keeper = theme_keeper(paid: true)
    theme_keeper.game_played
    @day = Date.new(2026, 11, 8)

    assert_equal [:classic, :halloween], theme_keeper.choices.map(&:key)
    assert theme_keeper.offered?
    assert_equal [:classic, :halloween], theme_keeper(paid: true).choices.map(&:key), "kept by the store"
  end

  def test_a_game_out_of_season_earns_nothing_and_a_missed_theme_returns_next_year
    @day = Date.new(2026, 11, 8)
    theme_keeper = theme_keeper(paid: true)
    theme_keeper.game_played

    assert_equal [:classic], theme_keeper.choices.map(&:key)
    refute theme_keeper.offered?

    @day = Date.new(2027, 10, 20)

    assert_equal [:classic, :halloween], theme_keeper.choices.map(&:key)
  end

  def test_a_theme_earned_while_free_is_kept_and_worn_on_purchase
    free = theme_keeper(paid: false)
    free.game_played
    @day = Date.new(2026, 11, 8)

    assert_predicate free.worn, :ordinary?
    assert_equal :halloween, theme_keeper(paid: false).choices.last.key

    @paid.write("paid")
    bought = theme_keeper(paid: false)

    assert_predicate bought, :offered?
    bought.wear(THEMES.find { it.key == :halloween })
    assert_equal :halloween, bought.worn.key
  end

  def test_a_chosen_style_is_kept_all_year_and_over_the_seasons_theme
    theme_keeper = theme_keeper(paid: true)
    theme_keeper.game_played
    theme_keeper.wear(THEMES.first)

    assert_predicate theme_keeper.worn, :ordinary?

    @day = Date.new(2026, 12, 20)
    theme_keeper.game_played

    assert_predicate theme_keeper(paid: true).worn, :ordinary?, "a choice stands over the season"
    theme_keeper.wear(THEMES.find { it.key == :winter })
    @day = Date.new(2027, 6, 1)

    assert_equal :winter, theme_keeper(paid: true).worn.key, "worn all year once chosen"
  end

  def test_nothing_unearned_or_out_of_season_can_be_worn
    @day = Date.new(2026, 11, 8)
    theme_keeper = theme_keeper(paid: true)
    theme_keeper.wear(THEMES.find { it.key == :valentine })

    assert_predicate theme_keeper.worn, :ordinary?
  end

  def test_the_style_changes_only_when_refreshed_so_a_game_is_never_dressed_twice
    theme_keeper = theme_keeper(paid: true)
    @day = Date.new(2026, 11, 8)

    assert_equal :halloween, theme_keeper.worn.key

    theme_keeper.refresh

    assert_predicate theme_keeper.worn, :ordinary?
  end

  def test_a_store_with_nonsense_in_it_is_a_new_theme_keeper
    @store.write("earned: ghosts halloween\nchosen: nonsense\njunk")
    theme_keeper = theme_keeper(paid: true)

    assert_equal [:classic, :halloween], theme_keeper.choices.map(&:key)
    assert_equal :halloween, theme_keeper.worn.key
  end

  def test_the_palette_is_the_worn_themes
    assert_same THEMES.find { it.key == :halloween }.palette, theme_keeper.palette
  end

  private

  def theme_keeper(paid: true)
    @paid.write("paid") if paid
    entitlement = DotPopper::Entitlement.new(@paid)
    ThemeKeeper.new(@store, themes: THEMES, entitlement:, today: -> { @day })
  end
end
