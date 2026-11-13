# frozen_string_literal: true

require "test_helper"

class StatsTest < Minitest::Test
  Stats = DotPopper::Stats
  GameStats = DotPopper::GameStats
  SMALL = DotPopper::SizeClass::SMALL
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def game(score: 10, dots_popped: 12, mistakes: 1, duration: 30.0, most_dots_in_a_row: 8, times_to_pop: [0.8, 2.5, 1.2])
    GameStats.start.with(score:, dots_popped:, mistakes:, duration:, most_dots_in_a_row:, times_to_pop:)
  end

  def add(stats, game, day: "d", size_class: MEDIUM) = stats.add(game, day:, size_class:)

  def test_a_game_adds_to_the_totals_and_the_records
    stats = add(Stats.new, game, day: "2026-11-05")
    records = stats.records_in(MEDIUM)

    assert_equal [1, 12, 1, 1, "2026-11-05"], [stats.games, stats.dots_popped, stats.mistakes, stats.days, stats.last_day]
    assert_in_delta 30.0, stats.seconds
    assert_equal 1, records.games
    assert_in_delta 30.0, records.longest_game
    assert_equal 8, records.most_dots_in_a_row
    assert_in_delta 0.8, records.shortest_time_to_pop
    assert_in_delta 2.5, records.longest_time_to_pop
    assert_equal [10], stats.recent
  end

  def test_a_day_counts_once_however_many_games_it_has
    stats = Stats.new
    %w[2026-11-05 2026-11-05 2026-11-06].each { stats = add(stats, game, day: it) }

    assert_equal 2, stats.days
    assert_equal 3, stats.games
  end

  def test_records_keep_the_better_of_old_and_new
    stats = add(add(Stats.new, game), game(duration: 12.0, most_dots_in_a_row: 3, times_to_pop: [4.0]))
    records = stats.records_in(MEDIUM)

    assert_in_delta 30.0, records.longest_game
    assert_equal 8, records.most_dots_in_a_row
    assert_in_delta 0.8, records.shortest_time_to_pop
    assert_in_delta 4.0, records.longest_time_to_pop
  end

  # A phone's crowded field and a big monitor's roomy one are different
  # contests, so each class of screen keeps records of its own; the totals
  # and the last scores take in every game.
  def test_each_class_of_screen_keeps_its_own_records_and_shares_the_totals
    stats = add(add(Stats.new, game(most_dots_in_a_row: 20, score: 30)), game(most_dots_in_a_row: 4, score: 5),
                size_class: SMALL)

    assert_equal 20, stats.records_in(MEDIUM).most_dots_in_a_row
    assert_equal 4, stats.records_in(SMALL).most_dots_in_a_row
    assert_equal 1, stats.records_in(SMALL).games
    assert_equal 0, stats.records_in(DotPopper::SizeClass::LARGE).games
    assert_equal 2, stats.games
    assert_equal [30, 5], stats.recent
  end

  # Each last score keeps the class it was played in, for the chart; a
  # file written before they were kept leaves its scores' unknown.
  def test_each_last_score_keeps_its_class_and_older_ones_are_unknown
    old = Stats.parse("games=2\nrecent=3,9\n")
    stats = add(add(old, game(score: 4)), game(score: 6), size_class: DotPopper::SizeClass::STANDARD)

    assert_equal [3, 9, 4, 6], stats.recent
    assert_equal [nil, nil, MEDIUM, DotPopper::SizeClass::STANDARD], stats.recent_classes
    assert_includes stats.to_text, "recent_classes=?,?,medium,fitted\n"
    assert_equal stats.recent_classes, Stats.parse(stats.to_text).recent_classes
  end

  def test_the_last_scores_classes_are_trimmed_with_them
    stats = Stats.new
    25.times { stats = add(stats, game(score: it), size_class: it.even? ? SMALL : MEDIUM) }

    assert_equal 20, stats.recent_classes.size
    assert_equal MEDIUM, stats.recent_classes.first
  end

  def test_a_record_is_judged_against_its_own_class_only
    stats = add(add(Stats.new, game(most_dots_in_a_row: 20)), game(most_dots_in_a_row: 4), size_class: SMALL)

    assert_equal [:most_dots_in_a_row], stats.records_set_by(game(most_dots_in_a_row: 6), SMALL).map(&:kind)
    assert_empty stats.records_set_by(game(most_dots_in_a_row: 6), MEDIUM).map(&:kind)
    assert_empty stats.records_set_by(game(most_dots_in_a_row: 60), DotPopper::SizeClass::LARGE),
                 "a class's first game has nothing to beat"
  end

  def test_a_game_with_no_dots_popped_has_no_shortest_time_to_pop
    assert_nil add(Stats.new, game(dots_popped: 0, times_to_pop: [])).records_in(MEDIUM).shortest_time_to_pop
  end

  def test_only_the_last_twenty_scores_are_kept
    stats = Stats.new
    25.times { stats = add(stats, game(score: it)) }

    assert_equal (5..24).to_a, stats.recent
  end

  def test_stats_are_what_a_game_beats_most_impressive_first
    before = add(Stats.new, game)
    better = game(duration: 41.0, most_dots_in_a_row: 9, times_to_pop: [0.4, 2.5])

    assert_equal %i[most_dots_in_a_row longest_game shortest_time_to_pop], before.records_set_by(better, MEDIUM).map(&:kind)
    assert_equal 9, before.records_set_by(better, MEDIUM).first.value
  end

  def test_the_first_game_sets_no_stats
    assert_empty Stats.new.records_set_by(game, MEDIUM)
  end

  def test_a_tie_as_the_game_shows_it_is_not_a_record
    before = add(Stats.new, game)

    assert_empty before.records_set_by(game(duration: 30.4, times_to_pop: [0.76, 2.54]), MEDIUM)
    assert_equal [:longest_time_to_pop], before.records_set_by(game(times_to_pop: [2.56]), MEDIUM).map(&:kind)
  end

  def test_it_saves_and_reads_back
    stats = add(add(Stats.new, game, day: "2026-11-05"), game(score: 3, times_to_pop: []), day: "2026-11-05",
                size_class: SMALL)
    stats = stats.with(streak: DotPopper::GoalStreak.new(current: 2, longest: 4, last_met: "2026-11-05"))

    assert_equal stats, Stats.parse(stats.to_text)
    assert_includes stats.to_text, "small.most_dots_in_a_row=8\n"
    refute Stats.old?(stats.to_text)
  end

  # Before records were kept by class, the file named them without one.
  # They go to the class the game is told is this screen's.
  def test_an_older_file_gives_its_records_to_this_screens_class
    old = "games=7\npops=80\nlongest_game=41.5\nmost_dots_in_a_row=12\nshortest_time_to_pop=0.4\nlongest_time_to_pop=5.5\nrecent=3,9\n"
    stats = Stats.parse(old, legacy: SMALL)

    assert Stats.old?(old)
    assert_equal 7, stats.games
    assert_equal [3, 9], stats.recent
    assert_equal [SMALL], stats.records.keys
    records = stats.records_in(SMALL)
    assert_equal [7, 41.5, 12, 0.4, 5.5],
                 [records.games, records.longest_game, records.most_dots_in_a_row, records.shortest_time_to_pop, records.longest_time_to_pop]
    assert_equal stats, Stats.parse(stats.to_text)
  end

  def test_a_missing_file_reads_as_nothing_yet
    assert_equal Stats.new, Stats.parse(nil)
    assert_equal Stats.new, Stats.parse("")
    refute Stats.old?(nil)
  end

  def test_a_damaged_file_keeps_what_it_can
    stats = Stats.parse("games=7\npops=lots\nmistakes=-3\nmedium.games=2\nmedium.longest_time_to_pop=nan\n" \
                                "last_day=yesterday\nrecent=4,x,09,5\n\u0000garbage\nmedium.shortest_time_to_pop=0.5\n" \
                                "huge.games=3\n")

    assert_equal 7, stats.games
    assert_equal 0, stats.dots_popped
    assert_equal 0, stats.mistakes
    assert_in_delta 0.0, stats.records_in(MEDIUM).longest_time_to_pop
    assert_nil stats.last_day
    assert_equal [4, 9, 5], stats.recent
    assert_in_delta 0.5, stats.records_in(MEDIUM).shortest_time_to_pop
    assert_equal [MEDIUM], stats.records.keys
  end
end
