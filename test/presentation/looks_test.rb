# frozen_string_literal: true

require_relative "presentation_helper"

# The Looks screen: offered on the Stats screen to a free player always,
# who sees every look and which are earned but wears none, and to a paid
# player once there is a look to choose; a card for each look, and the
# choice shown at once.
class LooksTest < Minitest::Test
  include PresentationTest

  SIZES = [[1200, 800], [800, 500], [400, 320], [400, 850], [850, 400]].freeze

  def setup
    @sounds = FakeSounds.new
    @day = Date.new(2026, 10, 31)
    @paid = DotPopper::ScoreRecord::Memory.new
  end

  def test_looks_are_offered_to_a_free_player_always_and_to_a_paid_one_with_a_look_to_choose
    show(paid: false)
    open_stats

    assert @show.looks_offered?
    assert @show.reach_of(:looks)

    @day = Date.new(2026, 11, 8)
    show(paid: false)
    open_stats

    assert @show.looks_offered?, "a free player is shown that looks exist, in season or not"

    @day = Date.new(2026, 10, 31)
    show(paid: true)
    open_stats

    assert @show.looks_offered?
    assert @show.reach_of(:looks)

    @day = Date.new(2026, 11, 8)
    show(paid: true)
    open_stats

    refute @show.looks_offered?, "nothing earned, and none in season"
  end

  def test_a_game_in_season_wears_the_theme_and_keeps_it_to_choose_after_the_season
    show(paid: true)

    assert_equal :halloween, @show.worn.key
    assert_same Look::THEMES[1].palette, @show.palette

    @day = Date.new(2027, 3, 1)
    @wardrobe.refresh
    open_stats

    assert_predicate @show.worn, :ordinary?
    assert_equal [:classic, :halloween], @show.looks.map(&:key)
    assert @show.looks_offered?
  end

  def test_choosing_a_look_wears_it_at_once_and_leaving_goes_back_to_the_stats
    show(paid: true)
    open_stats
    @show.open_looks

    assert_predicate @show, :looks?
    cards = @show.looks_layout.cards

    assert_equal [:classic, :halloween], cards.map { it.theme.key }
    classic = cards.first
    @show.tap(classic.rect.center_x, classic.rect.center_y)

    assert_predicate @show.worn, :ordinary?
    assert_same Look::PALETTE, @show.palette
    assert @show.looks?, "choosing does not leave"

    @show.back

    refute @show.looks?
    assert @show.stats?
    @show.back

    refute @show.stats?
  end

  def test_a_tap_on_a_card_of_a_look_not_offered_does_nothing_and_play_cannot_start_under_looks
    show(paid: true)
    open_stats
    @show.open_looks
    before = @show.palette
    @show.tap(1, 1)

    assert_same before, @show.palette
    assert_nil @show.play_reach
  end

  def test_a_free_player_sees_every_look_and_which_are_earned_and_wears_none
    show(paid: false)
    open_stats
    @show.open_looks

    assert_predicate @show, :looks?
    assert_equal Look::THEMES, @show.looks
    assert_predicate @show, :looks_locked?
    assert_equal %i[classic halloween], Look::THEMES.select { @show.look_earned?(it) }.map(&:key)
    assert_equal "Looks come with the full game", Look::WORDS.looks[:locked]
    before = @show.palette
    @show.tap(*card_center(Look::THEMES.last))

    assert_same before, @show.palette
    assert_equal Look::THEMES.first, @show.worn
  end

  def test_a_look_earned_while_free_shows_as_earned_and_is_worn_on_purchase
    show(paid: false)

    assert(@wardrobe.earned?(Look::THEMES.find { it.key == :halloween }))
    refute(@wardrobe.earned?(Look::THEMES.find { it.key == :winter }))
    @paid.write("paid")
    @wardrobe.refresh

    assert_equal :halloween, @wardrobe.worn.key
  end

  def test_the_looks_screen_leads_to_the_offer_only_where_a_store_can_complete_one
    show(paid: false)
    open_stats
    @show.open_looks

    refute(@show.controls.any? { it.name == :offer }, "no store, so nothing is offered")

    store = Struct.new(:status, :price) do
      def offered? = true
      def connect = nil
      def update(_seconds) = nil
    end.new(:ready, "$1.99")
    show(paid: false, storefront: store)
    open_stats
    @show.open_looks
    reach = @show.controls.find { it.name == :offer }.reach
    @show.tap(reach.center_x, reach.center_y)

    assert_predicate @show, :offer?
    refute_predicate @show, :looks?
  end

  def test_the_cards_fit_their_room_apart_from_each_other_and_from_back_at_every_size
    SIZES.product([false, true]).each do |(width, height), note|
      plan = LooksLayout.new(layout: layout(width, height), themes: Look::THEMES, look: Look::LOOKS, note:)
      rects = plan.cards.map(&:rect)
      back = layout(width, height).back_button
      whole = layout(width, height).safe

      assert_equal Look::THEMES.size, rects.size, "#{width}x#{height}"
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

  def test_the_looks_button_stays_clear_of_the_other_stats_buttons_at_every_size
    SIZES.each do |width, height|
      page = layout(width, height)
      others = [page.back_button, page.credits_button, page.clear_stats_button]

      others.each { refute page.looks_button.overlaps?(it), "#{width}x#{height}" }
      assert_operator page.looks_button.x, :>=, page.safe.x, "#{width}x#{height}"
      assert_operator page.looks_button.right, :<=, page.safe.right, "#{width}x#{height}"
      assert_operator page.looks_button.y, :>, page.safe.y, "#{width}x#{height}"
    end
  end

  private

  def card_center(theme)
    rect = @show.looks_layout.cards.find { it.theme == theme }.rect
    [rect.center_x, rect.center_y]
  end

  def show(paid:, **options)
    @paid.write("paid") if paid
    entitlement = DotPopper::Entitlement.new(@paid)
    store = DotPopper::ScoreRecord::Memory.new
    wardrobe = Wardrobe.new(store, themes: Look::THEMES, entitlement:, today: -> { @day })
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2), score_record: DotPopper::ScoreRecord.new(DotPopper::ScoreRecord::Memory.new))
    @wardrobe = wardrobe
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, entitlement:, wardrobe:,
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
