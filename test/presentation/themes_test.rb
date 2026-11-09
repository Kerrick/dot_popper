# frozen_string_literal: true

require_relative "presentation_helper"

# The Themes screen: offered on the Stats screen to every player alike, with a
# card for each theme, which are earned marked the same. A Pro player's tap
# wears one at once; a Free player's tap leads to the offer of Pro, and Back
# from it returns to this screen.
class ThemesTest < Minitest::Test
  include PresentationTest

  SIZES = [[1200, 800], [800, 500], [400, 320], [400, 850], [850, 400]].freeze

  def setup
    @sounds = FakeSounds.new
    @day = Date.new(2026, 10, 31)
    @pro = DotPopper::ScoreRecord::Memory.new
  end

  def test_themes_are_offered_alike_to_a_free_player_and_a_pro_one
    [Date.new(2026, 10, 31), Date.new(2026, 11, 8)].product([false, true]).each do |day, pro|
      @day = day
      show(pro:)
      open_stats

      assert @show.themes_offered?, "#{day}, pro #{pro}"
      assert @show.reach_of(:themes)
    end
  end

  def test_a_game_in_season_wears_the_theme_and_keeps_it_to_choose_after_the_season
    show(pro: true)

    assert_equal :halloween, @show.worn.key
    assert_same Style::THEMES[1].palette, @show.palette

    @day = Date.new(2027, 3, 1)
    @theme_keeper.refresh
    open_stats

    assert_predicate @show.worn, :ordinary?
    assert_equal Style::THEMES.map(&:key), @show.themes.map(&:key)
    assert @show.themes_offered?
  end

  def test_choosing_a_style_wears_it_at_once_and_leaving_goes_back_to_the_stats
    show(pro: true)
    open_stats
    @show.open_themes

    assert_predicate @show, :themes?
    cards = @show.themes_layout.cards

    assert_equal Style::THEMES.map(&:key), cards.map { it.theme.key }
    classic = cards.first
    @show.tap(classic.rect.center_x, classic.rect.center_y)

    assert_predicate @show.worn, :ordinary?
    assert_same Style::PALETTE, @show.palette
    assert @show.themes?, "choosing does not leave"

    @show.back

    refute @show.themes?
    assert @show.stats?
    @show.back

    refute @show.stats?
  end

  def test_a_tap_on_a_card_of_a_style_not_offered_does_nothing_and_play_cannot_start_under_themes
    show(pro: true)
    open_stats
    @show.open_themes
    before = @show.palette
    @show.tap(1, 1)

    assert_same before, @show.palette
    assert_nil @show.play_reach
  end

  def test_a_free_player_sees_every_theme_and_which_are_earned_and_a_tap_leads_to_pro
    show(pro: false)
    open_stats
    @show.open_themes

    assert_predicate @show, :themes?
    assert_equal Style::THEMES, @show.themes
    assert_equal %i[classic halloween], Style::THEMES.select { @show.theme_earned?(it) }.map(&:key)
    before = @show.palette
    @show.tap(*card_center(Style::THEMES.last))

    assert_same before, @show.palette
    assert_equal Style::THEMES.first, @show.worn
    assert_predicate @show, :offer?
    assert_equal :themes, @show.offer_focus
    assert_equal "Themes", @show.words.offer_items(@show.offer_focus).first
  end

  def test_back_from_the_offer_returns_to_the_themes_screen_as_it_was
    show(pro: false)
    open_stats
    @show.open_themes
    @show.tap(*card_center(Style::THEMES.last))
    @show.back

    refute_predicate @show, :offer?
    assert_predicate @show, :themes?
    assert_predicate @show, :stats?
    assert_nil @show.offer_focus
  end

  def test_a_pro_player_taps_a_theme_that_is_not_open_and_nothing_happens
    @day = Date.new(2026, 11, 8)
    show(pro: true)
    open_stats
    @show.open_themes
    winter = Style::THEMES.find { it.key == :winter }
    @show.tap(*card_center(winter))

    refute_predicate @show, :offer?
    assert_equal Style::THEMES.first, @show.worn
  end

  def test_a_theme_earned_while_free_shows_as_earned_and_is_worn_on_purchase
    show(pro: false)

    assert(@theme_keeper.earned?(Style::THEMES.find { it.key == :halloween }))
    refute(@theme_keeper.earned?(Style::THEMES.find { it.key == :winter }))
    @pro.write("pro")
    @theme_keeper.refresh

    assert_equal :halloween, @theme_keeper.worn.key
  end

  def test_the_themes_screen_has_no_pro_button_of_its_own
    show(pro: false)
    open_stats
    @show.open_themes

    refute(@show.controls.any? { it.name == :offer }, "the cards lead to Pro")
  end

  def test_the_cards_fit_their_room_apart_from_each_other_and_from_back_at_every_size
    SIZES.each do |width, height|
      plan = ThemesLayout.new(layout: layout(width, height), themes: Style::THEMES, style: Style::THEMES_LAYOUT)
      rects = plan.cards.map(&:rect)
      back = layout(width, height).back_button
      whole = layout(width, height).safe

      assert_equal Style::THEMES.size, rects.size, "#{width}x#{height}"
      rects.each do |rect|
        assert_operator rect.x, :>=, whole.x, "#{width}x#{height}"
        assert_operator rect.right, :<=, whole.right, "#{width}x#{height}"
        assert_operator rect.y, :>=, plan.heading_y, "#{width}x#{height}"
        assert_operator rect.bottom, :<=, back.y, "#{width}x#{height}"
        assert_operator rect.width, :>=, 90, "#{width}x#{height}: a card is big enough to read"
      end
      rects.combination(2) { |one, other| refute one.overlaps?(other), "#{width}x#{height}" }
    end
  end

  def test_the_themes_button_stays_clear_of_the_other_stats_buttons_at_every_size
    SIZES.each do |width, height|
      page = layout(width, height)
      others = [page.back_button, page.credits_button, page.clear_stats_button]

      others.each { refute page.themes_button.overlaps?(it), "#{width}x#{height}" }
      assert_operator page.themes_button.x, :>=, page.safe.x, "#{width}x#{height}"
      assert_operator page.themes_button.right, :<=, page.safe.right, "#{width}x#{height}"
      assert_operator page.themes_button.y, :>, page.safe.y, "#{width}x#{height}"
    end
  end

  private

  def card_center(theme)
    rect = @show.themes_layout.cards.find { it.theme == theme }.rect
    [rect.center_x, rect.center_y]
  end

  def show(pro:, **options)
    @pro.write("pro") if pro
    entitlement = DotPopper::Entitlement.new(@pro)
    store = DotPopper::ScoreRecord::Memory.new
    theme_keeper = ThemeKeeper.new(store, themes: Style::THEMES, entitlement:, today: -> { @day })
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2), score_record: DotPopper::ScoreRecord.new(DotPopper::ScoreRecord::Memory.new))
    @theme_keeper = theme_keeper
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, entitlement:, theme_keeper:,
                     stats_book: DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new, today: -> { @day }), **options)
    finish_game
  end

  def open_stats = @show.open_stats

  def finish_game
    press_main
    fresh = @cabinet.game.dots.find(&:fresh?)
    clear_around!(@cabinet.game, fresh)
    @show.tap(fresh.x, fresh.y)
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end
end
