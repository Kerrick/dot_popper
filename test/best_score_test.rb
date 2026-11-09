# frozen_string_literal: true

require "test_helper"

class BestScoreTest < Minitest::Test
  BestScore = DotPopper::BestScore
  SMALL = DotPopper::SizeClass::SMALL
  MEDIUM = DotPopper::SizeClass::MEDIUM
  LARGE = DotPopper::SizeClass::LARGE

  def test_it_reads_each_class_of_screens_best
    best = BestScore.new(BestScore::Memory.new("small=6\nmedium=24\n"))

    assert_equal 6, best.of(SMALL)
    assert_equal 24, best.of(MEDIUM)
    assert_equal 0, best.of(LARGE)
  end

  def test_a_missing_or_unreadable_record_counts_as_zero
    assert_equal 0, BestScore.new(BestScore::Memory.new).of(MEDIUM)
    assert_equal 0, BestScore.new(BestScore::Memory.new("lots")).of(MEDIUM)
    assert_equal 0, BestScore.new(BestScore::Memory.new("medium=-4\nhuge=9\nsmall")).of(MEDIUM)
  end

  def test_only_a_higher_score_for_its_own_class_is_recorded
    store = BestScore::Memory.new("small=5\nmedium=30\n")
    best = BestScore.new(store)

    refute best.record(5, SMALL)
    assert best.record(6, SMALL), "a phone's best is beaten on a phone, whatever a bigger screen's is"
    refute best.record(29, MEDIUM)
    assert_equal "small=6\nmedium=30\n", store.read
  end

  def test_a_classs_first_game_sets_its_best_but_is_no_new_best
    store = BestScore::Memory.new("small=5\n")
    best = BestScore.new(store)

    assert best.first?(LARGE)
    refute best.record(0, LARGE), "there was nothing to beat"
    refute best.first?(LARGE)
    assert_equal 0, best.of(LARGE)
    assert best.record(1, LARGE)
    assert_equal "small=5\nlarge=1\n", store.read
  end

  # A best saved before scores were kept by class is one bare number. It
  # belongs to the class of the screen the game opens on, and is saved in
  # the new form at once, so it stays there.
  def test_an_older_best_goes_to_this_screens_class_and_is_saved_again
    store = BestScore::Memory.new("12\n")
    best = BestScore.new(store, legacy: SMALL)

    assert_equal 12, best.of(SMALL)
    assert_equal 0, best.of(MEDIUM)
    assert_equal "small=12\n", store.read
    assert_equal 12, BestScore.new(store, legacy: LARGE).of(SMALL)
  end
end
