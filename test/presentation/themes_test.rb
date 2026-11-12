# frozen_string_literal: true

require_relative "presentation_helper"

# The Looks screen and the news of a new theme, as a Show runs them.
class ThemesTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @paid = false
    @day = Date.new(2026, 11, 8)
  end

  def show(paid:, unlocked: [])
    @paid = true if paid
    entitlement = DotPopper::Entitlement.new(forced: @paid)
    @theme_keeper = ThemeKeeper.new(DotPopper::ScoreRecord::Memory.new, themes: Style::THEMES, entitlement:)
    @theme_keeper.receive(unlocked)
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2), score_record: DotPopper::ScoreRecord.new(DotPopper::ScoreRecord::Memory.new))
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, entitlement:, theme_keeper: @theme_keeper,
                     stats_book: DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new, today: -> { @day }))
  end

  def test_nothing_of_a_theme_shows_until_the_server_unlocks_it
    show(paid: true)
    assert_nil @show.arrival
    refute_predicate @theme_keeper, :offered?
  end

  def test_a_new_theme_is_told_with_an_immediate_switch
    show(paid: true, unlocked: ["ghost"])
    assert_equal :ghost, @show.arrival.key
    use_key = @show.arrival_plan.use_button
    @show.tap(use_key.center_x, use_key.center_y)
    assert_equal :ghost, @show.in_use.key
    assert_nil @show.arrival, "told once"
  end

  def test_not_now_keeps_the_ordinary_theme_and_does_not_ask_again
    show(paid: true, unlocked: ["ghost"])
    later = @show.arrival_plan.later_button
    @show.tap(later.center_x, later.center_y)
    assert_predicate @show.in_use, :ordinary?
    assert_nil @show.arrival
  end

  def test_escape_declines
    show(paid: true, unlocked: ["ghost"])
    assert @show.back
    assert_nil @show.arrival
  end

  def test_the_card_comes_only_on_the_title
    show(paid: true, unlocked: ["ghost"])
    @show.open_stats rescue nil
    assert_nil @show.arrival
  end

  def test_a_free_player_can_be_told_and_is_led_to_pro
    show(paid: false, unlocked: ["ghost"])
    assert_equal :ghost, @show.arrival.key
    assert_equal "Get Pro", @show.arrival_use_word
    assert_predicate @show.in_use, :ordinary?
  end

  def test_the_switch_names_the_theme_it_uses
    show(paid: true, unlocked: ["ghost"])
    assert_equal "Use Ghost", @show.arrival_use_word
  end

  def test_the_longest_switch_and_not_now_both_fit_on_a_phone_either_way_up
    show(paid: true)
    [[400, 850], [850, 400]].each do |width, height|
      ["Get Pro", format(@show.words.themes.fetch(:use), "Jack-o'-lantern")].each do |word|
        plan = ArrivalPlan.new(layout: layout(width, height), word:)
        card = plan.card
        use = plan.use_button
        later = plan.later_button
        [use, later].each do |b|
          assert_operator b.x, :>=, card.x, "#{word} at #{width}x#{height}"
          assert_operator b.right, :<=, card.right, "#{word} at #{width}x#{height}"
          assert_operator b.bottom, :<=, card.bottom, "#{word} at #{width}x#{height}"
        end
        apart = use.right <= later.x || later.right <= use.x || use.bottom <= later.y || later.bottom <= use.y
        assert apart, "buttons overlap for #{word} at #{width}x#{height}"
        size = [(plan.button_height * 0.36).round, 40].min
        assert_operator RoughMeasure.new.width(:bold, size, word), :<=, use.width - plan.button_height, "#{word} at #{width}x#{height}"
      end
    end
  end
  # On a computer's window, the themes in as few rows as give each card
  # room for its name: one row while they fit, as seven do, then rows
  # of equal count; on a phone, two to a row, the first across the
  # whole width when the count is odd.
  def test_the_cards_stand_in_as_few_rows_as_fit_or_two_to_a_row
    seven = ThemesLayout.new(layout: layout(1200, 800), themes: Style::THEMES.first(7), style: Style::THEMES_LAYOUT).cards
    assert_equal [seven.first.rect.y], seven.map { it.rect.y }.uniq

    twelve = Array.new(12) { Style::THEMES[it % Style::THEMES.size] }
    wide = ThemesLayout.new(layout: layout(1200, 800), themes: twelve, style: Style::THEMES_LAYOUT).cards
    rows = wide.group_by { it.rect.y }.values
    assert_equal [6, 6], rows.map(&:size)
    wide.each { assert_operator it.rect.width, :>=, ThemesLayout::NARROWEST }
    assert_operator wide.map { it.rect.bottom }.max, :<=, layout(1200, 800).page.bottom

    themes = Style::THEMES

    narrow = ThemesLayout.new(layout: layout(400, 850), themes:, style: Style::THEMES_LAYOUT).cards
    first, *rest = narrow.map(&:rect)
    assert_operator first.width, :>, rest.first.width * 1.5, "the first spans the width" if themes.size.odd?
    assert_equal 2, rest.map(&:y).tally.values.max, "the rest two to a row"
  end

end
