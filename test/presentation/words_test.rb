# frozen_string_literal: true

require_relative "presentation_helper"

class WordsTest < Minitest::Test
  include PresentationTest

  def test_points_and_seconds_carry_their_sign
    assert_equal "+1", Words.points(1)
    assert_equal "−2", Words.points(-2)
    assert_equal "0", Words.points(0)
    assert_equal "+1s", Words.seconds(1.0)
    assert_equal "−2s", Words.seconds(-2.0)
    assert_equal "+1.5s", Words.seconds(1.5)
  end

  def test_the_minus_is_a_true_minus_sign
    assert_equal "−", Words.points(-1)[0]
  end

  def test_the_clock_shows_whole_seconds_and_never_less_than_zero
    assert_equal "9", Words.clock(DotPopper::Countdown.new(remaining: 9.7))
    assert_equal "0", Words.clock(DotPopper::Countdown.new(remaining: -3))
  end

  def test_the_copy_is_short
    words = Look::WORDS
    assert_equal "Best 12", words.best_line(12)
    labels = words.to_h.except(:covered)
    labels.each_value { |text| assert_operator text.split.size, :<=, 4, text }
    words.covered.each { |sentence| assert_operator sentence.split.size, :<=, 8, sentence }
  end

  def test_the_round_in_one_line
    stats = DotPopper::RoundStats.start.with(pops: 14, slips: 2, waits: [1.0, 3.14])

    assert_equal "14 pops · 2 slips · longest wait 3.1 s", Look::WORDS.summary(stats)
    assert_equal "1 pop · 1 slip · longest wait 0.0 s",
                 Look::WORDS.summary(DotPopper::RoundStats.start.with(pops: 1, slips: 1, waits: [0.0]))
    assert_equal "0 pops · 0 slips", Look::WORDS.summary(DotPopper::RoundStats.start)
  end

  def test_how_far_short_of_the_best
    assert_equal "3 short of your best (27)", Look::WORDS.short_of_best(24, 27)
    assert_equal "You matched your best (27)", Look::WORDS.short_of_best(27, 27)
  end
end
