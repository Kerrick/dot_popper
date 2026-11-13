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

  def test_the_score_record_is_named
    assert_equal "Your record: 12", Style::WORDS.score_record_line(12)
  end

  # The result to share names a new record or a tie, and otherwise only
  # the score.
  def test_the_shared_result_says_the_score_and_what_the_game_was
    stats = DotPopper::GameStats.start.with(dots_popped: 27, mistakes: 1, duration: 38.2)

    assert_equal "Dot Popper: 25 points, a new record!\n🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds",
                 Style::WORDS.share_text(25, stats, score_record: 25, new_score_record: true)
    assert_equal "Dot Popper: 25 points, tying my record!\n🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds",
                 Style::WORDS.share_text(25, stats, score_record: 25, new_score_record: false)
    assert_match(/\ADot Popper: 1 point\n/, Style::WORDS.share_text(1, stats, score_record: 25, new_score_record: false))
    assert_match(/\ADot Popper: 0 points\n/, Style::WORDS.share_text(0, stats, score_record: 0, new_score_record: false))
    assert_match(/\ADot Popper: 25 points\n/, Style::WORDS.share_text(25, stats, score_record: 25, new_score_record: false, first: true))
  end

  def test_the_shared_result_names_a_record_on_its_own_line
    stats = DotPopper::GameStats.start.with(dots_popped: 27, mistakes: 1, duration: 38.2)
    record = DotPopper::Stats::Record.new(kind: :most_dots_in_a_row, value: 18)

    assert_equal "Dot Popper: 25 points, a new record!\nNew record: 18 dots in a row without a mistake\n" \
                 "🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds",
                 Style::WORDS.share_text(25, stats, score_record: 25, new_score_record: true, record:)
  end

  # A score depends on how crowded the screen gets, so the shared result
  # says how big the screen was, counted in dots side by side.
  def test_the_shared_result_can_say_the_screen_it_was_played_on
    stats = DotPopper::GameStats.start.with(dots_popped: 27, mistakes: 1, duration: 38.2)
    screen = Style::WORDS.played_on(DotPopper::Field.new(1200, 800, 50))

    assert_equal "Played on a screen about 12 dots wide and 8 dots tall.", screen
    assert_equal "Dot Popper: 25 points\n🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds\n#{screen}",
                 Style::WORDS.share_text(25, stats, score_record: 30, new_score_record: false, screen:)
    assert_equal "This screen is about 4 dots wide and 9 dots tall.",
                 Style::WORDS.screen_here(DotPopper::Field.new(395, 850, 50))
    assert_equal [1, 1], Words.dots_across(DotPopper::Field.new(40, 20, 50)), "never no dots at all"
  end

  def test_each_record_reads_as_a_sentence
    record = ->(kind, value) { Style::WORDS.record(DotPopper::Stats::Record.new(kind:, value:)) }

    assert_equal "New record: 18 dots in a row without a mistake", record[:most_dots_in_a_row, 18]
    assert_equal "New record: your longest game, 48 seconds", record[:longest_game, 47.6]
    assert_equal "New record: your longest time to pop, 6.2 seconds", record[:longest_time_to_pop, 6.24]
    assert_equal "New record: your shortest time to pop, 0.3 seconds", record[:shortest_time_to_pop, 0.31]
  end

  # The main buttons name the gamepad's button that presses them.
  def test_the_prompts_name_the_press_the_player_is_making
    said = [InputKind::TOUCH, InputKind::MOUSE, InputKind::GAMEPAD].map do |kind|
      words = Style::WORDS.for(kind)
      [words.play, words.play_again, words.go_back, words.how_to_play]
    end

    assert_equal [["Play", "Play again", "Back", "How to play"], ["Play", "Play again", "Back", "How to play"],
                  ["Play (A)", "Play again (A)", "Back (B)", "How to play (Y)"]], said
    refute(said.flatten.any? { it.include?("anywhere") }, "no press goes anywhere")
  end

  # Holding "Clear my stats…" says what will go, and on a gamepad
  # names the button being held.
  def test_clearing_the_stats_says_what_goes_and_names_the_button
    mouse = Style::WORDS.for(InputKind::MOUSE)
    pad = Style::WORDS.for(InputKind::GAMEPAD)

    assert_equal "Keep holding to clear your records, totals, chart, achievements, and streak.", mouse.keep_holding("A")
    assert_equal "Keep holding Y to clear your records, totals, chart, achievements, and streak.", pad.keep_holding("Y")
    assert_equal ["Clear my stats…", "Hold Y to clear my stats…"], [mouse.clear, pad.clear]
    assert_equal ["Undo", "Undo (Y)"], [mouse.undo, pad.undo]
  end

  def test_a_computer_starts_with_the_mouse_and_a_phone_with_a_finger
    assert_equal InputKind::MOUSE, InputKind.starting(touch: false)
    assert_equal InputKind::TOUCH, InputKind.starting(touch: true)
  end

  # Game Over's facts are signs and numbers, with no word to translate.
  def test_the_game_in_signs_and_numbers
    stats = DotPopper::GameStats.start.with(dots_popped: 14, mistakes: 2, times_to_pop: [1.0, 3.14], duration: 33.6)

    assert_equal [[:bright, "14"], [:popped, "2"], [:stopwatch, "34s"]], Words.facts(stats)
    assert_equal [[:bright, "0"], [:popped, "0"], [:stopwatch, "0s"]], Words.facts(DotPopper::GameStats.start)
  end

  def test_a_long_time_reads_in_the_units_that_suit_it
    assert_equal "45 seconds", Words.duration(45.9)
    assert_equal "1 minute", Words.duration(61)
    assert_equal "31 minutes", Words.duration(1890)
    assert_equal "2 hours", Words.duration(7200)
    assert_equal "2 hours 5 minutes", Words.duration(7500)
  end

  def test_the_charts_caption_counts_the_games
    assert_equal "Your last 20 games", Words.last_games(20)
    assert_equal "Your last game", Words.last_games(1)
  end

  def test_every_goal_reads_as_a_whole_sentence
    DotPopper::DailyGoal::LIST.each do |goal|
      line = Style::WORDS.goal(goal)
      assert_match(/\AToday's goal: [a-z].*[a-z]\.\z/, line)
      assert_includes line, goal.target.to_s
    end
    assert_equal "Today's goal: pop 15 bright dots in a row without a mistake.",
                 Style::WORDS.goal(DotPopper::DailyGoal.new(kind: :clean_run, target: 15))
    assert_equal "Met 3 days in a row.", Style::WORDS.streak(3)
  end

  def test_wrapping_breaks_between_words_to_fit
    width = ->(text) { text.size }

    assert_equal ["Today's goal: pop", "15 bright dots"], Words.wrap("Today's goal: pop 15 bright dots", 17, &width)
    assert_equal ["short"], Words.wrap("short", 17, &width)
    assert_equal %w[unbreakably long], Words.wrap("unbreakably long", 5, &width)
  end

  def test_balancing_evens_out_the_lines_so_no_word_is_left_alone
    width = ->(text) { text.size }
    text = "Today's goal: keep one game going for 40 seconds."

    assert_equal "seconds.", Words.wrap(text, 42, &width).last
    balanced = Words.balance(text, 42, &width)
    assert_equal 2, balanced.size
    assert_operator balanced.map(&:size).minmax.then { |least, most| most - least }, :<=, 8
  end

  def test_how_far_short_of_the_score_record
    assert_equal "Just 3 points short of your record of 27", Style::WORDS.short_of_score_record(24, 27)
    assert_equal "Just 1 point short of your record of 27", Style::WORDS.short_of_score_record(26, 27)
    assert_equal "Your record is 28", Style::WORDS.short_of_score_record(5, 28), "a far-off best isn't a gap to dwell on"
    assert_equal "You tied your record of 27", Style::WORDS.short_of_score_record(27, 27)
    assert_equal "", Style::WORDS.short_of_score_record(0, 0), "no best to compare with yet"
    assert_equal "Your record: 27", Style::WORDS.short_of_score_record(27, 27, first: true), "a first game tied nothing"
  end

  def test_a_met_goal_still_says_what_it_was
    goal = DotPopper::DailyGoal.for(Date.new(2026, 11, 1))
    line = Style::WORDS.goal_done_line(goal)

    assert line.start_with?("Done today: ")
    assert_equal Style::WORDS.goal(goal).delete_prefix("Today's goal: "), line.delete_prefix("Done today: ")
  end
end
