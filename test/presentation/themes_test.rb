# frozen_string_literal: true

require_relative "presentation_helper"

# The Looks screen and the news of a new theme, as a Show runs them.
class ThemesTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @paid = DotPopper::ScoreRecord::Memory.new
    @day = Date.new(2026, 11, 8)
  end

  def show(paid:, unlocked: [])
    @paid.write("pro") if paid
    entitlement = DotPopper::Entitlement.new(@paid)
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
    wear = @show.arrival_plan.wear_button
    @show.tap(wear.center_x, wear.center_y)
    assert_equal :ghost, @show.worn.key
    assert_nil @show.arrival, "told once"
  end

  def test_not_now_keeps_the_ordinary_theme_and_does_not_ask_again
    show(paid: true, unlocked: ["ghost"])
    later = @show.arrival_plan.later_button
    @show.tap(later.center_x, later.center_y)
    assert_predicate @show.worn, :ordinary?
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
    assert_includes @show.arrival_wear_word, "Pro"
    assert_predicate @show.worn, :ordinary?
  end
end
