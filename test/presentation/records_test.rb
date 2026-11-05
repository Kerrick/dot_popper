# frozen_string_literal: true

require_relative "presentation_helper"

class RecordsTest < Minitest::Test
  include PresentationTest

  def stats
    bests = DotPopper::LifetimeStats::Bests.new(rounds: 40, longest_round: 47.6, longest_run: 18, fastest_pop: 0.34,
                                                longest_wait: 6.2)
    phone = DotPopper::LifetimeStats::Bests.new(rounds: 2, longest_round: 12.0, longest_run: 3)
    DotPopper::LifetimeStats.new(rounds: 42, pops: 812, slips: 61, seconds: 1890.0, days: 5, recent: [3, 9, 27, 12],
                                 streak: DotPopper::GoalStreak.new(current: 3, longest: 7, last_met: "2026-11-04"),
                                 bests: { MEDIUM => bests, DotPopper::SizeClass::SMALL => phone })
  end

  MEDIUM = DotPopper::SizeClass::MEDIUM

  def sheet = RecordsSheet.build(stats, best: 27, words: Look::WORDS, streak: 3, size_class: MEDIUM,
                                        field: DotPopper::Field.new(1200, 800, R))

  def test_the_sheet_shows_the_daily_goals_streaks
    assert_equal [["Days in a row you've met it", "3 days"], ["Most days in a row", "7 days"]],
                 sheet.goal.rows.map { [it.label, it.value] }
  end

  def test_the_sheet_lists_the_bests_and_the_totals_in_plain_words
    rows = sheet.bests.rows.to_h { [it.label, it.value] }

    assert_equal "Your bests on screens this size", sheet.bests.title
    assert_equal({ "Best score" => "27", "Longest round" => "48 seconds",
                   "Most pops in a row without a wrong tap" => "18", "Fastest pop" => "0.3 seconds",
                   "Longest wait that ended in a pop" => "6.2 seconds" }, rows)
    assert_equal [["Rounds played", "42"], ["Dots popped", "812"], ["Wrong taps", "61"], ["Time played", "31 minutes"],
                  ["Days played", "5"]], sheet.totals.rows.map { [it.label, it.value] }
    assert_equal [3, 9, 27, 12], sheet.scores
    refute sheet.empty
  end

  def test_the_bests_are_this_screens_and_the_totals_every_screens
    phone = RecordsSheet.build(stats, best: 6, words: Look::WORDS, size_class: DotPopper::SizeClass::SMALL,
                                      field: DotPopper::Field.new(395, 850, R))

    assert_equal ["6", "12 seconds", "3", "None yet"], phone.bests.rows.first(4).map(&:value)
    assert_equal "42", phone.totals.rows.first.value
    assert_equal "This screen is about 4 dots wide and 9 dots tall.", phone.notes.first
    assert_equal "This screen is about 12 dots wide and 8 dots tall.", sheet.notes.first
    assert_match(/sized to your screen/, sheet.notes.last)
  end

  def test_with_dots_sized_to_the_screen_the_sheet_says_so
    fitted = RecordsSheet.build(stats, best: 0, words: Look::WORDS, size_class: DotPopper::SizeClass::FITTED,
                                       field: DotPopper::Field.new(395, 850, 30),
                                       sizing: DotPopper::DotSizing::SIZED_TO_SCREEN)

    assert_equal "Your bests with dots sized to the screen", fitted.bests.title
    assert_equal ["None yet"], fitted.bests.rows.map(&:value).values_at(3)
    assert_equal ["Dots are sized to your screen, so every screen has the same room, and scores compare across devices."],
                 fitted.notes
  end

  def test_with_no_rounds_the_sheet_is_empty_and_says_none_yet
    empty = RecordsSheet.build(DotPopper::LifetimeStats.new, best: 0, words: Look::WORDS)

    assert empty.empty
    assert_equal "None yet", empty.bests.rows[3].value
  end

  def test_bars_stand_on_whole_pixels_with_the_best_marked
    pixels = Pixels.new(scale: 2)
    bars = ScoreBars.new(scores: [5, 10, 0, 10]).bars(Rect.new(x: 10.3, y: 0, width: 200, height: 100), pixels)

    assert_equal [false, false, false, true], bars.map(&:best), "the latest of a tie is the one marked"
    assert_in_delta 100.0, bars[1].height
    assert_in_delta 50.0, bars[0].height
    assert_in_delta 0.5, bars[2].height, 0.001, "a 0 is a stub one device pixel high"
    bars.each do |bar|
      [bar.x, bar.y, bar.width, bar.height].each { assert_in_delta (it * 2).round, it * 2, 1e-9 }
      assert_in_delta 100.0, bar.y + bar.height
    end
    assert_operator bars[0].x + bars[0].width, :<, bars[1].x, "bars have a gap between them"
  end

  def test_twenty_slots_leave_room_for_the_rounds_to_come
    bars = ScoreBars.new(scores: [4]).bars(Rect.new(x: 0, y: 0, width: 200, height: 50), Pixels.new(scale: 1))

    assert_operator bars.first.width, :<, 10
  end

  def test_a_wide_window_has_two_columns_and_a_narrow_one_stacks
    wide = RecordsLayout.new(layout: layout(1200, 800), sheet:, look: Look::RECORDS)
    narrow = RecordsLayout.new(layout: layout(400, 850), sheet:, look: Look::RECORDS)

    assert wide.wide?
    assert_equal 2, wide.placements.map(&:x).uniq.size
    refute narrow.wide?
    assert_equal 1, narrow.placements.map(&:x).uniq.size
  end

  def test_everything_fits_between_the_heading_and_the_prompt
    [[1200, 800], [400, 850], [400, 320], [800, 600], [2560, 1440]].each do |width, height|
      plan = RecordsLayout.new(layout: layout(width, height), sheet:, look: Look::RECORDS)
      assert_operator plan.note_y(0), :>, plan.heading_y, "#{width}x#{height}"
      plan.placements.each do |placed|
        assert_operator placed.y, :>, plan.note_y(0), "#{width}x#{height}"
        assert_operator placed.x, :>=, 0, "#{width}x#{height}"
        assert_operator placed.right, :<=, width, "#{width}x#{height}"
        assert_operator placed.y, :>, plan.heading_y, "#{width}x#{height}"
        bottom = placed.item == :chart ? placed.y + placed.height : placed.y
        assert_operator bottom, :<, plan.prompt_y, "#{width}x#{height}"
      end
      assert_operator plan.text_size, :>=, RecordsLayout::SMALLEST_TEXT
    end
  end

  def test_the_chart_leads_when_there_are_scores
    plan = RecordsLayout.new(layout: layout(400, 850), sheet:, look: Look::RECORDS)

    assert_equal ["Your last 4 rounds", :chart, "Your bests on screens this size"],
                 plan.placements.first(3).map(&:item)
  end
end
