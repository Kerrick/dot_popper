# frozen_string_literal: true

require_relative "presentation_helper"

# Clearing the records from the Stats screen: held, never tapped, and
# undone for a while after.
class ClearingStatsTest < Minitest::Test
  include PresentationTest

  HOLD = Style::RECORDS_CLEAR.hold
  UNDO = Style::RECORDS_CLEAR.undo

  def setup
    @sounds = FakeSounds.new
    @folder = DotPopper::StatsKeeper::Folder.new
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2), score_record: DotPopper::ScoreRecord.new(@folder.call("best")))
    @stats_book = DotPopper::StatsBook.new(@folder.call("stats"), today: -> { Date.new(2026, 11, 5) })
    @keeper = DotPopper::StatsKeeper.new(score_record: @cabinet.score_record, stats_book: @stats_book, folder: @folder)
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, stats_book: @stats_book, keeper: @keeper)
    finish_game
    @show.open_stats
  end

  def test_clear_is_offered_only_on_a_stats_screen_with_stats
    assert @show.clear_offered?
    @show.close_stats
    refute @show.clear_offered?
  end

  def test_holding_clear_my_stats_clears_them_and_offers_undo
    press_clear(:mouse)
    @show.update(HOLD - 0.1)
    assert @show.stats?, "the press never goes back"
    refute @show.stats.empty

    @show.update(0.1)
    assert @show.stats.empty, "the screen says there are no games yet"
    assert @show.undo_offer
    refute @show.clear_offered?
    assert_equal 0, @show.marquee.score_record
    assert_equal 0, @stats_book.stats.games
  end

  def test_letting_go_too_soon_changes_nothing
    press_clear(4)
    @show.update(HOLD - 0.1)
    @show.let_go(4)
    @show.update(HOLD)

    assert @show.stats?
    refute @show.stats.empty
    assert_equal 1, @stats_book.stats.games
    assert_in_delta HOLD, @show.clearing.let_go_ago(@show.now), 1e-9
  end

  def test_another_finger_letting_go_does_not_stop_the_hold
    press_clear(1)
    @show.let_go(2)
    @show.update(HOLD)

    assert @show.stats.empty
  end

  def test_undo_puts_everything_back
    before = @stats_book.stats
    score_record = @cabinet.score_record.of(@cabinet.size_class)
    clear_by(:mouse)
    @show.tap(*middle(@show.undo_reach), by: :mouse)

    assert @show.stats?, "Undo never goes back"
    refute @show.stats.empty
    assert_equal before, @stats_book.stats
    assert_equal score_record, @cabinet.score_record.of(@cabinet.size_class)
    assert_equal score_record, @show.marquee.score_record
    assert @show.clear_offered?
  end

  def test_undo_is_offered_for_a_while_then_the_clearing_stands
    clear_by(:mouse)
    @show.update(UNDO)

    assert_nil @show.undo_offer
    assert @show.stats.empty
    assert_nil @show.undo_reach
    @show.tap(*middle(@show.layout.undo_button))
    assert @show.stats?, "where Undo was is empty space, which does nothing"
  end

  def test_a_game_ends_the_offer
    clear_by(:mouse)
    @show.close_stats
    press_main
    @show.open_stats

    assert_nil @show.undo_offer
  end

  def test_a_gamepads_y_holds_clear_and_then_undoes
    @show.clear_or_undo(:y)
    assert_equal "Y", @show.holding_button
    @show.update(HOLD)
    assert @show.stats.empty

    @show.clear_or_undo(:y)
    refute @show.stats.empty
  end

  def test_going_back_or_losing_focus_stops_the_hold
    press_clear(:mouse)
    @show.let_go_of_everything
    @show.update(HOLD)
    refute @show.stats.empty

    press_clear(:mouse)
    @show.back
    @show.update(HOLD)
    @show.open_stats
    refute @show.stats.empty
  end

  private

  def press_clear(by) = @show.tap(*middle(@show.clear_reach), by:)

  def clear_by(by)
    press_clear(by)
    @show.update(HOLD)
    @show.let_go(by)
  end

  def middle(rect) = [rect.center_x, rect.center_y]

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
