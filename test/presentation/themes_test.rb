# frozen_string_literal: true

require_relative "presentation_helper"

# The Looks screen: offered on the Stats screen to a free player always,
# who sees every look and which are earned but wears none, and to a pro
# player once there is a look to choose; a card for each look, and the
# choice shown at once.
class ThemesTest < Minitest::Test
  include PresentationTest

  SIZES = [[1200, 800], [800, 500], [400, 320], [400, 850], [850, 400]].freeze

  def setup
    @sounds = FakeSounds.new
    @day = Date.new(2026, 10, 31)
    @pro = DotPopper::ScoreRecord::Memory.new
  end

  def test_themes_are_offered_to_a_free_player_always_and_to_a_pro_one_with_a_style_to_choose
    show(pro: false)
    open_stats

    assert @show.themes_offered?
    assert @show.reach_of(:themes)

    @day = Date.new(2026, 11, 8)
    show(pro: false)
    open_stats

    assert @show.themes_offered?, "a free player is shown that looks exist, in season or not"

    @day = Date.new(2026, 10, 31)
    show(pro: true)
    open_stats

    assert @show.themes_offered?
    assert @show.reach_of(:themes)

    @day = Date.new(2026, 11, 8)
    show(pro: true)
    open_stats

    refute @show.themes_offered?, "nothing earned, and none in season"
  end

  def test_a_game_in_season_wears_the_theme_and_keeps_it_to_choose_after_the_season
    show(pro: true)

    assert_equal :halloween, @show.worn.key
    assert_same Style::THEMES[1].palette, @show.palette

    @day = Date.new(2027, 3, 1)
    @theme_keeper.refresh
    open_stats

    assert_predicate @show.worn, :ordinary?
    assert_equal [:classic, :halloween], @show.themes.map(&:key)
    assert @show.themes_offered?
  end

  def test_choosing_a_style_wears_it_at_once_and_leaving_goes_back_to_the_stats
    show(pro: true)
    open_stats
    @show.open_themes

    assert_predicate @show, :themes?
    cards = @show.themes_layout.cards

    assert_equal [:classic, :halloween], cards.map { it.theme.key }
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

  def test_a_free_player_sees_every_style_and_which_are_earned_and_wears_none
    show(pro: false)
    open_stats
    @show.open_themes

    assert_predicate @show, :themes?
    assert_equal Style::THEMES, @show.themes
    assert_predicate @show, :themes_locked?
    assert_equal %i[classic halloween], Style::THEMES.select { @show.theme_earned?(it) }.map(&:key)
    assert_equal "Looks come with the full game", Style::WORDS.themes[:locked]
    before = @show.palette
    @show.tap(*card_center(Style::THEMES.last))

    assert_same before, @show.palette
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

  def test_the_themes_screen_leads_to_the_offer_only_where_a_store_can_complete_one
    show(pro: false)
    open_stats
    @show.open_themes

    refute(@show.controls.any? { it.name == :offer }, "no store, so nothing is offered")

    store = Struct.new(:status, :price) do
      def offered? = true
      def connect = nil
      def update(_seconds) = nil
    end.new(:ready, "$1.99")
    show(pro: false, storefront: store)
    open_stats
    @show.open_themes
    reach = @show.controls.find { it.name == :offer }.reach
    @show.tap(reach.center_x, reach.center_y)

    assert_predicate @show, :offer?
    refute_predicate @show, :themes?
  end

  def test_the_cards_fit_their_room_apart_from_each_other_and_from_back_at_every_size
    SIZES.product([false, true]).each do |(width, height), note|
      plan = ThemesLayout.new(layout: layout(width, height), themes: Style::THEMES, style: Style::THEMES_LAYOUT, note:)
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
