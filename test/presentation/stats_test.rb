# frozen_string_literal: true

require_relative "presentation_helper"

class StatsSheetTest < Minitest::Test
  include PresentationTest

  def stats
    records = DotPopper::Stats::Records.new(games: 40, longest_game: 47.6, most_dots_in_a_row: 18, shortest_time_to_pop: 0.34,
                                                longest_time_to_pop: 6.2)
    phone = DotPopper::Stats::Records.new(games: 2, longest_game: 12.0, most_dots_in_a_row: 3)
    DotPopper::Stats.new(games: 42, pops: 812, mistakes: 61, seconds: 1890.0, days: 5, recent: [3, 9, 27, 12],
                                 recent_classes: [MEDIUM] * 4,
                                 streak: DotPopper::GoalStreak.new(current: 3, longest: 7, last_met: "2026-11-04"),
                                 records: { MEDIUM => records, DotPopper::SizeClass::SMALL => phone })
  end

  MEDIUM = DotPopper::SizeClass::MEDIUM

  def sheet = StatsSheet.build(stats, score_record: 27, words: Style::WORDS, streak: 3, size_class: MEDIUM,
                                        field: DotPopper::Field.new(1200, 800, R))

  def test_the_sheet_shows_the_daily_goals_streaks
    assert_equal [["Days in a row you've met it", "3 days"], ["Most days in a row", "7 days"]],
                 sheet.goal.rows.map { [it.label, it.value] }
  end

  def test_the_sheet_lists_the_records_and_the_totals_in_plain_words
    rows = sheet.records.rows.to_h { [it.label, it.value] }

    assert_equal "Your records with standard dots on screens this size", sheet.records.title
    assert_equal({ "Highest score" => "27", "Longest game" => "48 seconds",
                   "Most dots in a row without a mistake" => "18", "Shortest Time to Pop" => "0.3 seconds",
                   "Longest Time to Pop" => "6.2 seconds" }, rows)
    assert_equal [["Games played", "42"], ["Dots popped", "812"], ["Mistakes", "61"], ["Time played", "31 minutes"],
                  ["Days played", "5"]], sheet.totals.rows.map { [it.label, it.value] }
    assert_equal [3, 9, 27, 12], sheet.scores
    refute sheet.empty
  end

  def test_the_records_are_this_screens_and_the_totals_every_screens
    phone = StatsSheet.build(stats, score_record: 6, words: Style::WORDS, size_class: DotPopper::SizeClass::SMALL,
                                      field: DotPopper::Field.new(395, 850, R))

    assert_equal ["6", "12 seconds", "3", "None yet"], phone.records.rows.first(4).map(&:value)
    assert_equal "42", phone.totals.rows.first.value
    assert_equal "This screen is about 4 dots wide and 9 dots tall.", phone.notes.first
    assert_equal "This screen is about 12 dots wide and 8 dots tall.", sheet.notes.first
    assert_equal 1, sheet.notes.size, "one short line, with the usual dot size"
  end

  def test_with_dots_sized_to_the_screen_the_sheet_says_so
    fitted = StatsSheet.build(stats, score_record: 0, words: Style::WORDS, size_class: DotPopper::SizeClass::FITTED,
                                       field: DotPopper::Field.new(395, 850, 30),
                                       sizing: DotPopper::DotSizing::SIZED_TO_SCREEN)

    assert_equal "Your records with dots sized to the screen", fitted.records.title
    assert_equal ["None yet"], fitted.records.rows.map(&:value).values_at(3)
    assert_equal ["This screen is about 7 dots wide and 14 dots tall.",
                  "Dots are sized to fit this screen, so scores compare across devices."], fitted.notes
  end

  def test_with_no_games_the_sheet_is_empty_and_says_none_yet
    empty = StatsSheet.build(DotPopper::Stats.new, score_record: 0, words: Style::WORDS)

    assert empty.empty
    assert_equal "None yet", empty.records.rows[3].value
  end

  def test_bars_stand_on_whole_pixels_with_the_score_record_marked
    pixels = Pixels.new(scale: 2)
    bars = ScoreBars.new(scores: [5, 10, 0, 10]).bars(Rect.new(x: 10.3, y: 0, width: 200, height: 100), pixels)

    assert_equal [false, false, false, true], bars.map(&:score_record), "the latest of a tie is the one marked"
    assert_in_delta 100.0, bars[1].height
    assert_in_delta 50.0, bars[0].height
    assert_in_delta 0.5, bars[2].height, 0.001, "a 0 is a stub one device pixel high"
    bars.each do |bar|
      [bar.x, bar.y, bar.width, bar.height].each { assert_in_delta (it * 2).round, it * 2, 1e-9 }
      assert_in_delta 100.0, bar.y + bar.height
    end
    assert_operator bars[0].x + bars[0].width, :<, bars[1].x, "bars have a gap between them"
  end

  # A game from another group of screen and dot size is drawn faint and
  # is never the best, but keeps its true height, so the chart has one
  # scale.
  def test_bars_from_other_groups_are_dim_and_never_the_score_record
    bars = ScoreBars.new(scores: [5, 10, 8], mine: [true, false, true])
                    .bars(Rect.new(x: 0, y: 0, width: 200, height: 100), Pixels.new(scale: 1))

    assert_equal [false, true, false], bars.map(&:dim)
    assert_equal [false, false, true], bars.map(&:score_record)
    assert_in_delta 100.0, bars[1].height
  end

  def test_the_chart_dims_other_groups_games_and_says_so
    mixed = stats.with(recent_classes: [nil, DotPopper::SizeClass::SMALL, MEDIUM, MEDIUM])
    sheet = StatsSheet.build(mixed, score_record: 27, words: Style::WORDS, size_class: MEDIUM)
    fitted = StatsSheet.build(mixed, score_record: 0, words: Style::WORDS, size_class: DotPopper::SizeClass::FITTED,
                                       sizing: DotPopper::DotSizing::SIZED_TO_SCREEN)

    assert_equal [false, false, true, true], sheet.mine, "an old game's group is unknown"
    assert_equal "Brighter bars are games with standard dots on screens this size.", sheet.chart_note
    assert_equal "Brighter bars are games with dots sized to the screen.", fitted.chart_note
    assert_nil StatsSheet.build(stats, score_record: 27, words: Style::WORDS, size_class: MEDIUM).chart_note,
               "with every bar bright there is nothing to explain"
    plan = StatsLayout.new(layout: layout(400, 850), sheet:, style: Style::RECORDS)
    assert_equal ["Your last 4 games", :chart, ChartNote.new(text: sheet.chart_note)],
                 plan.placements.first(3).map(&:item)
  end

  def test_twenty_slots_leave_room_for_the_games_to_come
    bars = ScoreBars.new(scores: [4]).bars(Rect.new(x: 0, y: 0, width: 200, height: 50), Pixels.new(scale: 1))

    assert_operator bars.first.width, :<, 10
  end

  def test_a_wide_window_has_two_columns_and_a_narrow_one_stacks
    wide = StatsLayout.new(layout: layout(1200, 800), sheet:, style: Style::RECORDS)
    narrow = StatsLayout.new(layout: layout(400, 850), sheet:, style: Style::RECORDS)

    assert wide.wide?
    assert_equal 2, wide.placements.map(&:x).uniq.size
    refute narrow.wide?
    assert_equal 1, narrow.placements.map(&:x).uniq.size
  end

  def test_everything_fits_between_the_heading_and_the_prompt
    [[1200, 800], [400, 850], [400, 320], [800, 600], [2560, 1440]].each do |width, height|
      plan = StatsLayout.new(layout: layout(width, height), sheet:, style: Style::RECORDS)
      assert_operator plan.note_y(0), :>, plan.heading_y, "#{width}x#{height}"
      plan.placements.each do |placed|
        assert_operator placed.y, :>, plan.note_y(0), "#{width}x#{height}"
        assert_operator placed.x, :>=, 0, "#{width}x#{height}"
        assert_operator placed.right, :<=, width, "#{width}x#{height}"
        assert_operator placed.y, :>, plan.heading_y, "#{width}x#{height}"
        bottom = placed.item == :chart ? placed.y + placed.height : placed.y
        assert_operator bottom, :<, plan.prompt_y, "#{width}x#{height}"
      end
      assert_operator plan.text_size, :>=, StatsLayout::SMALLEST_TEXT
    end
  end

  def test_the_chart_leads_when_there_are_scores
    plan = StatsLayout.new(layout: layout(400, 850), sheet:, style: Style::RECORDS)

    assert_equal ["Your last 4 games", :chart, "Your records with standard dots on screens this size"],
                 plan.placements.first(3).map(&:item)
  end

  # A column is only as wide as its longest row needs, so a label stays
  # near its number, and the columns stay centred together.
  def test_columns_are_as_wide_as_their_rows_need_and_centred
    plan = StatsLayout.new(layout: layout(1200, 800), sheet:, style: Style::RECORDS, widest: 400)
    lefts = plan.placements.map(&:x).uniq

    assert plan.wide?
    assert_equal [400], plan.placements.map(&:width).uniq
    assert_in_delta 600, (lefts.min + lefts.max + 400) / 2.0, 0.01
  end

  def test_two_columns_only_when_both_fit_side_by_side
    refute StatsLayout.new(layout: layout(1000, 800), sheet:, style: Style::RECORDS, widest: 520).wide?
    assert StatsLayout.new(layout: layout(1000, 800), sheet:, style: Style::RECORDS, widest: 420).wide?
  end
end
