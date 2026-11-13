# frozen_string_literal: true

require_relative "presentation_helper"

class ThemeKeeperTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory
  THEMES = Style::THEMES

  def setup
    @store = Memory.new
  end

  def theme_keeper = ThemeKeeper.new(@store, themes: THEMES)

  # The theme in use, as UseCases::UseTheme says, for a player with Pro
  # or without.
  def use_theme(keeper, pro:) = DotPopper::UseCases::UseTheme.new(themes: keeper.rules, entitlement: DotPopper::Entitlement.new(forced: pro))

  def test_until_the_server_says_so_there_is_no_trace_of_a_theme
    w = theme_keeper
    assert_equal [THEMES.first], w.choices
    refute_predicate w, :offered?
    assert_nil w.arrival
  end

  def test_unlocks_are_kept_for_good_even_if_the_server_forgets
    w = theme_keeper
    assert w.receive(%w[ghost awake]), "the server sent new themes"
    assert_equal %i[classic ghost awake], w.choices.map(&:key)
    w.receive([])
    assert_equal %i[classic ghost awake], theme_keeper.choices.map(&:key), "still there, after a restart, offline"
  end

  def test_keys_the_game_does_not_know_are_ignored
    theme_keeper.receive(%w[zombie classic])
    assert_equal [THEMES.first], theme_keeper.choices
  end

  # Jingle bell was a theme in playtest builds and is gone from the game,
  # but the server still lists it and devices still have it saved.
  def test_a_removed_theme_saved_on_a_device_gives_way_to_the_ordinary_one_and_the_rest_are_kept
    @store.write("unlocked: ghost jingle_bell turkey\ntold: ghost jingle_bell\nchosen: jingle_bell\n")
    w = theme_keeper
    assert_equal %i[classic ghost turkey], w.choices.map(&:key)
    assert_predicate w.chosen, :ordinary?
    assert_equal :classic, use_theme(w, pro: true).current
    assert_equal :turkey, w.arrival.key, "only a theme the game has is told"
  end

  def test_a_removed_theme_the_server_still_sends_is_ignored
    w = theme_keeper
    refute w.receive(%w[jingle_bell]), "nothing new"
    assert_equal [THEMES.first], w.choices
    assert w.receive(%w[jingle_bell ghost])
    assert_equal %i[classic ghost], theme_keeper.choices.map(&:key)
  end

  def test_each_new_theme_is_told_once_and_a_pro_player_can_use_it
    w = theme_keeper
    w.receive(["ghost"])
    assert_equal :ghost, w.arrival.key
    w.told(w.arrival)
    assert_nil w.arrival, "told, however it was answered"
    assert_equal :used, use_theme(w, pro: true).call(w.choices.last.key)
    assert_equal :ghost, theme_keeper.chosen.key
    assert_equal :ghost, use_theme(theme_keeper, pro: true).current, "still in use after a restart"
  end

  def test_a_free_player_may_know_of_a_theme_but_uses_the_ordinary_one
    w = theme_keeper
    w.receive(["ghost"])
    assert_predicate w, :offered?
    assert_equal :ghost, w.arrival.key
    free = use_theme(w, pro: false)
    assert_predicate free, :locked?
    assert_equal :offer, free.call(w.choices.last.key)
    assert_equal :classic, free.current
    assert_predicate w.chosen, :ordinary?, "nothing is chosen for them"
  end

  def test_a_theme_chosen_with_pro_is_not_in_use_without_it
    w = theme_keeper
    w.receive(["ghost"])
    use_theme(w, pro: true).call(w.choices.last.key)

    assert_equal :classic, use_theme(w, pro: false).current
  end

  def test_choosing_the_current_theme_or_one_not_open_changes_nothing
    w = theme_keeper
    pro = use_theme(w, pro: true)

    assert_equal :same, pro.call(w.ordinary.key)
    assert_equal :same, pro.call(THEMES.last.key)
    assert_equal :classic, pro.current
  end
end
