# frozen_string_literal: true

require "test_helper"

class ScoreRecordTest < Minitest::Test
  ScoreRecord = DotPopper::ScoreRecord
  SMALL = DotPopper::SizeClass::SMALL
  MEDIUM = DotPopper::SizeClass::MEDIUM
  LARGE = DotPopper::SizeClass::LARGE

  def test_it_reads_each_class_of_screens_score_record
    score_record = ScoreRecord.new(ScoreRecord::Memory.new("small=6\nmedium=24\n"))

    assert_equal 6, score_record.of(SMALL)
    assert_equal 24, score_record.of(MEDIUM)
    assert_equal 0, score_record.of(LARGE)
  end

  def test_a_missing_or_unreadable_record_counts_as_zero
    assert_equal 0, ScoreRecord.new(ScoreRecord::Memory.new).of(MEDIUM)
    assert_equal 0, ScoreRecord.new(ScoreRecord::Memory.new("lots")).of(MEDIUM)
    assert_equal 0, ScoreRecord.new(ScoreRecord::Memory.new("medium=-4\nhuge=9\nsmall")).of(MEDIUM)
  end

  def test_only_a_higher_score_for_its_own_class_is_recorded
    store = ScoreRecord::Memory.new("small=5\nmedium=30\n")
    score_record = ScoreRecord.new(store)

    refute score_record.record(5, SMALL)
    assert score_record.record(6, SMALL), "a phone's best is beaten on a phone, whatever a bigger screen's is"
    refute score_record.record(29, MEDIUM)
    assert_equal "small=6\nmedium=30\n", store.read
  end

  def test_a_classs_first_game_sets_its_score_record_but_is_no_new_score_record
    store = ScoreRecord::Memory.new("small=5\n")
    score_record = ScoreRecord.new(store)

    assert score_record.first?(LARGE)
    refute score_record.record(0, LARGE), "there was nothing to beat"
    refute score_record.first?(LARGE)
    assert_equal 0, score_record.of(LARGE)
    assert score_record.record(1, LARGE)
    assert_equal "small=5\nlarge=1\n", store.read
  end

  # A best saved before scores were kept by class is one bare number. It
  # belongs to the class of the screen the game opens on, and is saved in
  # the new form at once, so it stays there.
  def test_an_older_score_record_goes_to_this_screens_class_and_is_saved_again
    store = ScoreRecord::Memory.new("12\n")
    score_record = ScoreRecord.new(store, legacy: SMALL)

    assert_equal 12, score_record.of(SMALL)
    assert_equal 0, score_record.of(MEDIUM)
    assert_equal "small=12\n", store.read
    assert_equal 12, ScoreRecord.new(store, legacy: LARGE).of(SMALL)
  end
end
