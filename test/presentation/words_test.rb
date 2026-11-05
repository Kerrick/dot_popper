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
end
