# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Using a theme: only Pro uses one other than the ordinary, and a Free
# player's choice leads to the offer instead.
class UseThemeTest < Minitest::Test
  # The themes the game keeps, as a local fake: :plain is the ordinary
  # one, and only the open ones may be chosen.
  class Themes
    attr_reader :chosen

    def initialize(open:) = (@open = open) && (@chosen = :plain)
    def ordinary = :plain
    def open?(theme) = @open.include?(theme)
    def use(theme) = @chosen = theme
  end

  def setup
    @themes = Themes.new(open: %i[plain ghost])
  end

  def use_theme(pro:) = DotPopper::UseCases::UseTheme.new(themes: @themes, entitlement: DotPopper::Entitlement.new(forced: pro))

  def test_pro_uses_an_open_theme_at_once
    pro = use_theme(pro: true)

    assert_equal :used, pro.call(:ghost)
    assert_equal :ghost, pro.current
    assert_equal :ghost, @themes.chosen
  end

  def test_the_current_theme_or_one_not_open_changes_nothing
    pro = use_theme(pro: true)

    assert_equal :same, pro.call(:plain)
    assert_equal :same, pro.call(:eclipse)
    assert_equal :plain, @themes.chosen
  end

  def test_a_free_player_is_offered_pro_and_keeps_the_ordinary_theme
    free = use_theme(pro: false)

    assert_predicate free, :locked?
    assert_equal :offer, free.call(:ghost)
    assert_equal :plain, free.current
    assert_equal :plain, @themes.chosen
  end

  def test_a_choice_made_with_pro_is_current_only_while_pro_lasts
    use_theme(pro: true).call(:ghost)

    assert_equal :plain, use_theme(pro: false).current
    assert_equal :ghost, use_theme(pro: true).current
  end

  def test_pro_arriving_changes_the_current_theme_only_once_it_is_taken_up
    entitlement = DotPopper::Entitlement.test
    @themes.use(:ghost)
    theme = DotPopper::UseCases::UseTheme.new(themes: @themes, entitlement:)
    entitlement.prove(DotPopper::Receipt.issue)

    assert_equal :plain, theme.current, "never mid-game"
    theme.refresh
    assert_equal :ghost, theme.current
  end

  # With the game's own Themes: a theme a Pro player chose is current
  # after a restart, and a saved choice of a theme since removed gives way
  # to the ordinary one.
  def test_with_the_games_themes_a_choice_lasts_and_a_removed_one_gives_way
    store = DotPopper::ScoreRecord::Memory.new("unlocked: ghost jingle_bell\ntold: ghost\nchosen: jingle_bell\n")
    pro = DotPopper::Entitlement.new(forced: true)
    theme = DotPopper::UseCases::UseTheme.new(themes: DotPopper::Themes.new(store), entitlement: pro)

    assert_equal :classic, theme.current
    assert_equal :used, theme.call(:ghost)
    assert_equal :ghost, DotPopper::UseCases::UseTheme.new(themes: DotPopper::Themes.new(store), entitlement: pro).current
  end
end
