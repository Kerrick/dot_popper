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
  end

  # The result to share names a new best or a tie, and otherwise only
  # the score.
  def test_the_shared_result_says_the_score_and_what_the_round_was
    stats = DotPopper::RoundStats.start.with(pops: 27, slips: 1, duration: 38.2)

    assert_equal "Dot Popper: 25 points, a new best!\n🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds",
                 Look::WORDS.share_text(25, stats, best: 25, new_best: true)
    assert_equal "Dot Popper: 25 points, tying my best!\n🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds",
                 Look::WORDS.share_text(25, stats, best: 25, new_best: false)
    assert_match(/\ADot Popper: 1 point\n/, Look::WORDS.share_text(1, stats, best: 25, new_best: false))
    assert_match(/\ADot Popper: 0 points\n/, Look::WORDS.share_text(0, stats, best: 0, new_best: false))
  end

  def test_the_shared_result_names_a_record_on_its_own_line
    stats = DotPopper::RoundStats.start.with(pops: 27, slips: 1, duration: 38.2)
    record = DotPopper::LifetimeStats::Record.new(kind: :longest_run, value: 18)

    assert_equal "Dot Popper: 25 points, a new best!\nNew record: 18 pops in a row without a wrong tap\n" \
                 "🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds",
                 Look::WORDS.share_text(25, stats, best: 25, new_best: true, record:)
  end

  def test_each_record_reads_as_a_sentence
    record = ->(kind, value) { Look::WORDS.record(DotPopper::LifetimeStats::Record.new(kind:, value:)) }

    assert_equal "New record: 18 pops in a row without a wrong tap", record[:longest_run, 18]
    assert_equal "New record: your longest round, 48 seconds", record[:longest_round, 47.6]
    assert_equal "New record: you waited 6.2 seconds for a dot, then popped it", record[:longest_wait, 6.24]
    assert_equal "New record: your fastest pop, 0.3 seconds after the dot appeared", record[:fastest_pop, 0.31]
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

  def test_a_long_time_reads_in_the_units_that_suit_it
    assert_equal "45 seconds", Words.duration(45.9)
    assert_equal "1 minute", Words.duration(61)
    assert_equal "31 minutes", Words.duration(1890)
    assert_equal "2 hours", Words.duration(7200)
    assert_equal "2 hours 5 minutes", Words.duration(7500)
  end

  def test_the_charts_caption_counts_the_rounds
    assert_equal "Your last 20 rounds", Words.last_rounds(20)
    assert_equal "Your last round", Words.last_rounds(1)
  end

  def test_how_far_short_of_the_best
    assert_equal "3 points short of your best of 27", Look::WORDS.short_of_best(24, 27)
    assert_equal "1 point short of your best of 27", Look::WORDS.short_of_best(26, 27)
    assert_equal "You tied your best of 27", Look::WORDS.short_of_best(27, 27)
    assert_equal "", Look::WORDS.short_of_best(0, 0), "no best to compare with yet"
  end
end
