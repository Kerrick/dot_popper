# frozen_string_literal: true

require "test_helper"

class BestScoreTest < Minitest::Test
  def test_it_reads_what_the_store_holds
    assert_equal 12, DotPopper::BestScore.new(DotPopper::BestScore::Memory.new("12\n")).value
  end

  def test_a_missing_or_unreadable_record_counts_as_zero
    assert_equal 0, DotPopper::BestScore.new(DotPopper::BestScore::Memory.new).value
    assert_equal 0, DotPopper::BestScore.new(DotPopper::BestScore::Memory.new("lots")).value
  end

  def test_only_a_higher_score_is_recorded
    store = DotPopper::BestScore::Memory.new("5")
    best = DotPopper::BestScore.new(store)

    refute best.record(5)
    assert best.record(6)
    assert_equal "6", store.read
  end
end
