# frozen_string_literal: true

require "test_helper"

# Which themes a player has, by key: a theme other than the ordinary one
# exists for them only once the server has released it, or, once setdef
# has been gone long enough, once its date has passed.
class ThemesTest < Minitest::Test
  Memory = DotPopper::ScoreRecord::Memory
  Theme = DotPopper::Theme
  Continuity = DotPopper::Continuity

  def setup
    @store = Memory.new
  end

  def themes = DotPopper::Themes.new(@store)

  def test_the_ordinary_theme_comes_first_and_every_key_is_its_own
    assert_predicate Theme::ALL.first, :ordinary?
    assert_equal [:classic], Theme::ALL.select(&:ordinary?).map(&:key)
    assert_equal Theme::ALL.map(&:key).uniq, Theme::ALL.map(&:key)
    assert_nil Theme::ALL.first.opens_on
    assert_predicate Theme::ALL, :frozen?
  end

  def test_until_the_server_says_so_there_is_no_trace_of_a_theme
    t = themes
    assert_equal [:classic], t.choices
    refute_predicate t, :offered?
    assert_nil t.new_theme
    assert_equal :classic, t.chosen
  end

  def test_releases_are_kept_for_good_even_if_the_server_forgets
    t = themes
    assert t.release(%w[ghost awake]), "the server sent new themes"
    assert_equal %i[classic ghost awake], t.choices
    refute t.release([])
    assert_equal %i[classic ghost awake], themes.choices, "still there, after a restart, offline"
  end

  def test_keys_the_game_does_not_know_and_the_ordinary_theme_are_ignored
    refute themes.release(%w[zombie classic])
    assert_equal [:classic], themes.choices
  end

  # Jingle bell was a theme in playtest builds and is gone from the game,
  # but the server still lists it and devices still have it saved.
  def test_a_removed_theme_saved_on_a_device_gives_way_to_the_ordinary_one_and_the_rest_are_kept
    @store.write("unlocked: ghost jingle_bell turkey\ntold: ghost jingle_bell\nchosen: jingle_bell\n")
    t = themes
    assert_equal %i[classic ghost turkey], t.choices
    assert_equal :classic, t.chosen
    assert_equal :turkey, t.new_theme, "only a theme the game has is told"
  end

  def test_a_removed_theme_the_server_still_sends_is_ignored
    t = themes
    refute t.release(%w[jingle_bell]), "nothing new"
    assert t.release(%w[jingle_bell ghost])
    assert_equal %i[classic ghost], themes.choices
  end

  def test_each_new_theme_is_told_once
    t = themes
    t.release(%w[ghost turkey])
    assert_equal :ghost, t.new_theme
    t.told(:ghost)
    assert_equal :turkey, t.new_theme
    t.told(:turkey)
    assert_nil t.new_theme, "told, however it was answered"
    assert_nil themes.new_theme, "and still, after a restart"
  end

  def test_a_theme_is_chosen_only_once_it_is_released
    t = themes
    t.use(:ghost)
    assert_equal :classic, t.chosen
    t.release(["ghost"])
    assert_equal :classic, t.chosen, "a choice made before it was released was never kept"
    assert t.open?(:ghost)
    refute t.open?(:turkey)
    t.use(:ghost)
    assert_equal :ghost, themes.chosen, "still chosen after a restart"
  end

  def test_what_is_saved_is_three_lines_in_the_order_they_came
    t = themes
    t.release(%w[turkey ghost])
    t.told(:turkey)
    t.use(:ghost)
    assert_equal "unlocked: turkey ghost\ntold: turkey\nchosen: ghost\n", @store.read
  end

  def test_a_saved_choice_no_longer_in_the_game_is_written_back_as_it_was
    @store.write("unlocked: ghost\ntold: \nchosen: jingle_bell\n")
    themes.told(:ghost)
    assert_equal "unlocked: ghost\ntold: ghost\nchosen: jingle_bell\n", @store.read
  end

  def test_themes_open_by_their_dates_only_once_setdef_has_been_gone_180_days
    t = themes
    today = Date.new(2027, 6, 1)

    refute t.open_by_date(today, 179)
    assert_equal [:classic], t.choices
    assert t.open_by_date(today, 180)
    assert_equal %i[ghost gingerbread jack_o_lantern ornament peppermint pumpkin_pie santa snowman turkey], (t.choices - [:classic]).sort
    refute t.open_by_date(Date.new(2027, 9, 30), 400), "awake and eclipse wait for their day"
    assert t.open_by_date(Date.new(2027, 10, 1), 400)
    assert_equal Theme::ALL.map(&:key), t.choices
  end

  def test_a_theme_opens_on_its_date_and_not_the_day_before
    refute themes.open_by_date(Date.new(2026, 9, 30), 400)
    assert themes.open_by_date(Date.new(2026, 10, 1), 400)
    assert_equal %i[classic ghost jack_o_lantern], themes.choices
  end

  def test_a_check_that_leaves_setdef_gone_long_enough_opens_themes_by_their_dates
    t = themes
    gone = Continuity::Gone.new(Memory.new).subscribe(t)
    gone.heard(:gone, Date.new(2027, 1, 1))
    assert_equal [:classic], t.choices

    gone.heard(:unknown, Date.new(2027, 7, 1))
    assert_includes t.choices, :ghost
  end

  def test_setdef_answering_opens_nothing
    t = themes
    t.call(Continuity::SetdefHere.new)
    assert_equal [:classic], t.choices
  end
end
