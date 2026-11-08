# frozen_string_literal: true

require_relative "presentation_helper"

class WardrobeTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::BestScore::Memory
  THEMES = Look::THEMES

  def setup
    @store = Memory.new
    @paid = Memory.new
    @day = Date.new(2026, 10, 31)
  end

  def test_a_free_player_always_wears_the_ordinary_look_even_in_season
    wardrobe = wardrobe(paid: false)

    assert_predicate wardrobe.worn, :ordinary?
    refute_predicate wardrobe, :offered?
  end

  def test_a_paid_player_wears_the_theme_in_season_and_the_ordinary_look_out_of_it
    assert_equal :halloween, wardrobe.worn.key
    @day = Date.new(2026, 11, 8)

    assert_predicate wardrobe.worn, :ordinary?
  end

  def test_one_round_in_season_earns_a_theme_for_good
    wardrobe = wardrobe(paid: true)
    wardrobe.round_played
    @day = Date.new(2026, 11, 8)

    assert_equal [:classic, :halloween], wardrobe.choices.map(&:key)
    assert wardrobe.offered?
    assert_equal [:classic, :halloween], wardrobe(paid: true).choices.map(&:key), "kept by the store"
  end

  def test_a_round_out_of_season_earns_nothing_and_a_missed_theme_returns_next_year
    @day = Date.new(2026, 11, 8)
    wardrobe = wardrobe(paid: true)
    wardrobe.round_played

    assert_equal [:classic], wardrobe.choices.map(&:key)
    refute wardrobe.offered?

    @day = Date.new(2027, 10, 20)

    assert_equal [:classic, :halloween], wardrobe.choices.map(&:key)
  end

  def test_a_theme_earned_while_free_is_kept_and_worn_on_purchase
    free = wardrobe(paid: false)
    free.round_played
    @day = Date.new(2026, 11, 8)

    assert_predicate free.worn, :ordinary?
    assert_equal :halloween, wardrobe(paid: false).choices.last.key

    @paid.write("paid")
    bought = wardrobe(paid: false)

    assert_predicate bought, :offered?
    bought.wear(THEMES.find { it.key == :halloween })
    assert_equal :halloween, bought.worn.key
  end

  def test_a_chosen_look_is_kept_all_year_and_over_the_seasons_theme
    wardrobe = wardrobe(paid: true)
    wardrobe.round_played
    wardrobe.wear(THEMES.first)

    assert_predicate wardrobe.worn, :ordinary?

    @day = Date.new(2026, 12, 20)
    wardrobe.round_played

    assert_predicate wardrobe(paid: true).worn, :ordinary?, "a choice stands over the season"
    wardrobe.wear(THEMES.find { it.key == :winter })
    @day = Date.new(2027, 6, 1)

    assert_equal :winter, wardrobe(paid: true).worn.key, "worn all year once chosen"
  end

  def test_nothing_unearned_or_out_of_season_can_be_worn
    @day = Date.new(2026, 11, 8)
    wardrobe = wardrobe(paid: true)
    wardrobe.wear(THEMES.find { it.key == :valentine })

    assert_predicate wardrobe.worn, :ordinary?
  end

  def test_the_look_changes_only_when_refreshed_so_a_round_is_never_dressed_twice
    wardrobe = wardrobe(paid: true)
    @day = Date.new(2026, 11, 8)

    assert_equal :halloween, wardrobe.worn.key

    wardrobe.refresh

    assert_predicate wardrobe.worn, :ordinary?
  end

  def test_a_store_with_nonsense_in_it_is_a_new_wardrobe
    @store.write("earned: ghosts halloween\nchosen: nonsense\njunk")
    wardrobe = wardrobe(paid: true)

    assert_equal [:classic, :halloween], wardrobe.choices.map(&:key)
    assert_equal :halloween, wardrobe.worn.key
  end

  def test_the_palette_is_the_worn_looks
    assert_same THEMES.find { it.key == :halloween }.palette, wardrobe.palette
  end

  private

  def wardrobe(paid: true)
    @paid.write("paid") if paid
    entitlement = DotPopper::Entitlement.new(@paid)
    Wardrobe.new(@store, themes: THEMES, entitlement:, today: -> { @day })
  end
end
