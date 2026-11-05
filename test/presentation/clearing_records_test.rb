# frozen_string_literal: true

require_relative "presentation_helper"

# Clearing the records from the Records screen: held, never tapped, and
# undone for a while after.
class ClearingRecordsTest < Minitest::Test
  include PresentationTest

  HOLD = Look::RECORDS_CLEAR.hold
  UNDO = Look::RECORDS_CLEAR.undo

  def setup
    @sounds = FakeSounds.new
    @folder = DotPopper::RecordKeeper::Folder.new
    @game = DotPopper::Game.new(field, random: Random.new(2), best: DotPopper::BestScore.new(@folder.call("best")))
    @lifetime = DotPopper::Lifetime.new(@folder.call("lifetime"), today: -> { Date.new(2026, 11, 5) })
    @keeper = DotPopper::RecordKeeper.new(best: @game.best, lifetime: @lifetime, folder: @folder)
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, lifetime: @lifetime, keeper: @keeper)
    finish_round
    @show.open_records
  end

  def test_clear_is_offered_only_on_a_records_screen_with_records
    assert @show.clear_offered?
    @show.close_records
    refute @show.clear_offered?
  end

  def test_holding_clear_my_records_clears_them_and_offers_undo
    press_clear(:mouse)
    @show.update(HOLD - 0.1)
    assert @show.records?, "the press never goes back"
    refute @show.records.empty

    @show.update(0.1)
    assert @show.records.empty, "the screen says there are no rounds yet"
    assert @show.undo_offer
    refute @show.clear_offered?
    assert_equal 0, @show.marquee.best
    assert_equal 0, @lifetime.stats.rounds
  end

  def test_letting_go_too_soon_changes_nothing
    press_clear(4)
    @show.update(HOLD - 0.1)
    @show.let_go(4)
    @show.update(HOLD)

    assert @show.records?
    refute @show.records.empty
    assert_equal 1, @lifetime.stats.rounds
    assert_in_delta HOLD, @show.clearing.let_go_ago(@show.now), 1e-9
  end

  def test_another_finger_letting_go_does_not_stop_the_hold
    press_clear(1)
    @show.let_go(2)
    @show.update(HOLD)

    assert @show.records.empty
  end

  def test_undo_puts_everything_back
    before = @lifetime.stats
    best = @game.best.of(@game.size_class)
    clear_by(:mouse)
    @show.tap(*middle(@show.undo_reach), by: :mouse)

    assert @show.records?, "Undo never goes back"
    refute @show.records.empty
    assert_equal before, @lifetime.stats
    assert_equal best, @game.best.of(@game.size_class)
    assert_equal best, @show.marquee.best
    assert @show.clear_offered?
  end

  def test_undo_is_offered_for_a_while_then_the_clearing_stands
    clear_by(:mouse)
    @show.update(UNDO)

    assert_nil @show.undo_offer
    assert @show.records.empty
    @show.tap(*middle(@show.undo_reach))
    refute @show.records?, "where Undo was is an ordinary tap, which goes back"
  end

  def test_a_round_ends_the_offer
    clear_by(:mouse)
    @show.close_records
    @show.tap(10, 10)
    @show.open_records

    assert_nil @show.undo_offer
  end

  def test_a_gamepads_y_holds_clear_and_then_undoes
    @show.clear_or_undo(:y)
    assert_equal "Y", @show.holding_button
    @show.update(HOLD)
    assert @show.records.empty

    @show.clear_or_undo(:y)
    refute @show.records.empty
  end

  def test_going_back_or_losing_focus_stops_the_hold
    press_clear(:mouse)
    @show.let_go_of_everything
    @show.update(HOLD)
    refute @show.records.empty

    press_clear(:mouse)
    @show.back
    @show.update(HOLD)
    @show.open_records
    refute @show.records.empty
  end

  # A cleared device's title is a new player's, but for "Your records"
  # and the dot-size choice: those are the player's, not records.
  def test_the_title_after_clearing_shows_no_best_or_goal_but_keeps_its_buttons
    clear_by(:mouse)
    @show.close_records
    plan = @show.title_plan

    assert_nil plan[:best]
    assert_nil plan[:goal]
    assert @show.records_offered?
    refute @show.played?
  end

  private

  def press_clear(by) = @show.tap(*middle(@show.clear_reach), by:)

  def clear_by(by)
    press_clear(by)
    @show.update(HOLD)
    @show.let_go(by)
  end

  def middle(rect) = [rect.center_x, rect.center_y]

  def finish_round
    @show.tap(10, 10)
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @show.tap(fresh.x, fresh.y)
    @game.update(20)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(10, 10)
  end
end
