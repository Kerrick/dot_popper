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

  def test_the_best_score_is_named
    assert_equal "Your best: 12", Look::WORDS.best_line(12)
    assert_equal "Your best today: 9", Look::WORDS.daily_best_line(9)
  end

  # The title teaches the scoring in words a first-time player can act on,
  # with the numbers taken from the rules.
  def test_the_legend_says_what_each_tap_does
    assert_equal "Tap a bright dot: +1 point, +1 second", Look::WORDS.legend_fresh
    assert_equal "Tap a popped dot: −2 points, −2 seconds", Look::WORDS.legend_popped
  end

  def test_the_round_in_one_line
    stats = DotPopper::RoundStats.start.with(pops: 14, slips: 2, waits: [1.0, 3.14])

    assert_equal "14 pops, 2 wrong taps, slowest pop 3.1 seconds", Look::WORDS.summary(stats)
    assert_equal "1 pop, 1 wrong tap, slowest pop 0.0 seconds",
                 Look::WORDS.summary(DotPopper::RoundStats.start.with(pops: 1, slips: 1, waits: [0.0]))
    assert_equal "0 pops, 0 wrong taps", Look::WORDS.summary(DotPopper::RoundStats.start)
  end

  def test_how_far_short_of_the_best
    assert_equal "3 points short of your best of 27", Look::WORDS.short_of_best(24, 27)
    assert_equal "1 point short of your best of 27", Look::WORDS.short_of_best(26, 27)
    assert_equal "You tied your best of 27", Look::WORDS.short_of_best(27, 27)
    assert_equal "", Look::WORDS.short_of_best(0, 0), "no best to compare with yet"
  end
end
