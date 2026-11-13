# frozen_string_literal: true

require_relative "presentation_helper"

class StatsSheetTest < Minitest::Test
  include PresentationTest

  def stats
    records = DotPopper::Stats::RecordSet.new(games: 40, longest_game: 47.6, most_dots_in_a_row: 18, shortest_time_to_pop: 0.34,
                                                longest_time_to_pop: 6.2)
    phone = DotPopper::Stats::RecordSet.new(games: 2, longest_game: 12.0, most_dots_in_a_row: 3)
    DotPopper::Stats.new(games: 42, dots_popped: 812, mistakes: 61, seconds: 1890.0, days: 5, recent: [3, 9, 27, 12],
                                 recent_classes: [MEDIUM] * 4,
                                 streak: DotPopper::GoalStreak.new(current: 3, longest: 7, last_met: "2026-11-04"),
                                 records: { MEDIUM => records, DotPopper::SizeClass::SMALL => phone })
  end

  MEDIUM = DotPopper::SizeClass::MEDIUM

  def sheet = StatsSheet.build(stats, score_record: 27, words: Style::WORDS, streak: 3, size_class: MEDIUM,
                                        field: DotPopper::Field.new(1200, 800, R))

  def test_the_sheet_shows_the_daily_goals_streaks
    assert_equal [["Days in a row", "3 days"], ["Most days in a row", "7 days"]],
                 sheet.goal.rows.map { [it.label, it.value] }
  end

  def test_the_sheet_lists_the_records_and_the_totals_in_plain_words
    rows = sheet.records.rows.to_h { [it.label, it.value] }

    assert_equal "Your stats on screens this size", sheet.records.heading, "on the 24 × 16 R window the sizes look alike, and neither is named"
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

  def test_with_standard_dots_the_sheet_says_so
    phone = DotPopper::Field.new(395, 850, R)
    fitted = StatsSheet.build(stats, score_record: 0, words: Style::WORDS, size_class: DotPopper::SizeClass::FITTED,
                                       field: DotPopper::Field.new(395, 850, 30),
                                       sizing: DotPopper::DotSizing::SIZED_TO_SCREEN, preview: SizingPreview.of(phone, Style::SIZING))

    assert_equal "Your stats with standard dots", fitted.records.heading
    assert_equal ["None yet"], fitted.records.rows.map(&:value).values_at(3)
    assert_equal ["This screen is about 7 dots wide and 14 dots tall."], fitted.notes
  end

  # The other size is named as Settings names it here: "Bigger" on a
  # phone, "Smaller" on a big monitor.
  def test_with_the_other_size_the_sheet_names_it_as_settings_does
    phone = DotPopper::Field.new(395, 850, R)
    monitor = DotPopper::Field.new(3008, 1692, R)
    bigger = StatsSheet.build(stats, score_record: 6, words: Style::WORDS, size_class: DotPopper::SizeClass::SMALL, field: phone,
                                       preview: SizingPreview.of(phone, Style::SIZING))
    smaller = StatsSheet.build(stats, score_record: 6, words: Style::WORDS, size_class: DotPopper::SizeClass::LARGE, field: monitor,
                                        preview: SizingPreview.of(monitor, Style::SIZING))

    assert_equal "Your stats with bigger dots on screens this size", bigger.records.heading
    assert_equal "Brighter bars are games that count here.", bigger.chart_note
    assert_equal "Your stats with smaller dots on screens this size", smaller.records.heading
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
  # is never marked as the record, but keeps its true height, so the chart has one
  # scale.
  def test_bars_from_other_groups_are_dim_and_never_the_score_record
    bars = ScoreBars.new(scores: [5, 10, 8], mine: [true, false, true])
                    .bars(Rect.new(x: 0, y: 0, width: 200, height: 100), Pixels.new(scale: 1))

    assert_equal [false, true, false], bars.map(&:dim)
    assert_equal [false, false, true], bars.map(&:score_record)
    assert_in_delta 100.0, bars[1].height
  end

  def test_twenty_slots_leave_room_for_the_games_to_come
    bars = ScoreBars.new(scores: [4]).bars(Rect.new(x: 0, y: 0, width: 200, height: 50), Pixels.new(scale: 1))

    assert_operator bars.first.width, :<, 10
  end

end
