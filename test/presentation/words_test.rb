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
    assert_match(/\ADot Popper: 25 points\n/, Look::WORDS.share_text(25, stats, best: 25, new_best: false, first: true))
  end

  def test_the_shared_result_names_a_record_on_its_own_line
    stats = DotPopper::RoundStats.start.with(pops: 27, slips: 1, duration: 38.2)
    record = DotPopper::LifetimeStats::Record.new(kind: :longest_run, value: 18)

    assert_equal "Dot Popper: 25 points, a new best!\nNew record: 18 pops in a row without a wrong tap\n" \
                 "🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds",
                 Look::WORDS.share_text(25, stats, best: 25, new_best: true, record:)
  end

  # A score depends on how crowded the screen gets, so the shared result
  # says how big the screen was, counted in dots side by side.
  def test_the_shared_result_can_say_the_screen_it_was_played_on
    stats = DotPopper::RoundStats.start.with(pops: 27, slips: 1, duration: 38.2)
    screen = Look::WORDS.played_on(DotPopper::Field.new(1200, 800, 50))

    assert_equal "Played on a screen about 12 dots wide and 8 dots tall.", screen
    assert_equal "Dot Popper: 25 points\n🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds\n#{screen}",
                 Look::WORDS.share_text(25, stats, best: 30, new_best: false, screen:)
    assert_equal "This screen is about 4 dots wide and 9 dots tall.",
                 Look::WORDS.screen_here(DotPopper::Field.new(395, 850, 50))
    assert_equal [1, 1], Words.dots_across(DotPopper::Field.new(40, 20, 50)), "never no dots at all"
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

  def test_every_goal_reads_as_a_whole_sentence
    DotPopper::DailyGoal::LIST.each do |goal|
      line = Look::WORDS.goal(goal)
      assert_match(/\AToday's goal: [a-z].*[a-z]\.\z/, line)
      assert_includes line, goal.target.to_s
    end
    assert_equal "Today's goal: pop 15 bright dots in a row without tapping a popped one.",
                 Look::WORDS.goal(DotPopper::DailyGoal.new(kind: :clean_run, target: 15))
    assert_equal "You've met the daily goal 3 days in a row.", Look::WORDS.streak(3)
  end

  def test_wrapping_breaks_between_words_to_fit
    width = ->(text) { text.size }

    assert_equal ["Today's goal: pop", "15 bright dots"], Words.wrap("Today's goal: pop 15 bright dots", 17, &width)
    assert_equal ["short"], Words.wrap("short", 17, &width)
    assert_equal %w[unbreakably long], Words.wrap("unbreakably long", 5, &width)
  end

  def test_balancing_evens_out_the_lines_so_no_word_is_left_alone
    width = ->(text) { text.size }
    text = "Today's goal: keep one round going for 40 seconds."

    assert_equal "seconds.", Words.wrap(text, 42, &width).last
    balanced = Words.balance(text, 42, &width)
    assert_equal 2, balanced.size
    assert_operator balanced.map(&:size).minmax.then { |least, most| most - least }, :<=, 8
  end

  def test_how_far_short_of_the_best
    assert_equal "3 points short of your best of 27", Look::WORDS.short_of_best(24, 27)
    assert_equal "1 point short of your best of 27", Look::WORDS.short_of_best(26, 27)
    assert_equal "You tied your best of 27", Look::WORDS.short_of_best(27, 27)
    assert_equal "", Look::WORDS.short_of_best(0, 0), "no best to compare with yet"
    assert_equal "Your best: 27", Look::WORDS.short_of_best(27, 27, first: true), "a first round tied nothing"
  end
end
