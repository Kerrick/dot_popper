# frozen_string_literal: true

require "test_helper"

class LifetimeStatsTest < Minitest::Test
  LifetimeStats = DotPopper::LifetimeStats
  GameStats = DotPopper::GameStats
  SMALL = DotPopper::SizeClass::SMALL
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def game(score: 10, pops: 12, slips: 1, duration: 30.0, longest_run: 8, waits: [0.8, 2.5, 1.2])
    GameStats.start.with(score:, pops:, slips:, duration:, longest_run:, waits:)
  end

  def add(stats, game, day: "d", size_class: MEDIUM) = stats.add(game, day:, size_class:)

  def test_a_game_adds_to_the_totals_and_the_bests
    stats = add(LifetimeStats.new, game, day: "2026-11-05")
    bests = stats.bests_in(MEDIUM)

    assert_equal [1, 12, 1, 1, "2026-11-05"], [stats.games, stats.pops, stats.slips, stats.days, stats.last_day]
    assert_in_delta 30.0, stats.seconds
    assert_equal 1, bests.games
    assert_in_delta 30.0, bests.longest_game
    assert_equal 8, bests.longest_run
    assert_in_delta 0.8, bests.fastest_pop
    assert_in_delta 2.5, bests.longest_wait
    assert_equal [10], stats.recent
  end

  def test_a_day_counts_once_however_many_games_it_has
    stats = LifetimeStats.new
    %w[2026-11-05 2026-11-05 2026-11-06].each { stats = add(stats, game, day: it) }

    assert_equal 2, stats.days
    assert_equal 3, stats.games
  end

  def test_bests_keep_the_better_of_old_and_new
    stats = add(add(LifetimeStats.new, game), game(duration: 12.0, longest_run: 3, waits: [4.0]))
    bests = stats.bests_in(MEDIUM)

    assert_in_delta 30.0, bests.longest_game
    assert_equal 8, bests.longest_run
    assert_in_delta 0.8, bests.fastest_pop
    assert_in_delta 4.0, bests.longest_wait
  end

  # A phone's crowded field and a big monitor's roomy one are different
  # contests, so each class of screen keeps bests of its own; the totals
  # and the last scores take in every game.
  def test_each_class_of_screen_keeps_its_own_bests_and_shares_the_totals
    stats = add(add(LifetimeStats.new, game(longest_run: 20, score: 30)), game(longest_run: 4, score: 5),
                size_class: SMALL)

    assert_equal 20, stats.bests_in(MEDIUM).longest_run
    assert_equal 4, stats.bests_in(SMALL).longest_run
    assert_equal 1, stats.bests_in(SMALL).games
    assert_equal 0, stats.bests_in(DotPopper::SizeClass::LARGE).games
    assert_equal 2, stats.games
    assert_equal [30, 5], stats.recent
  end

  # Each last score keeps the class it was played in, for the chart; a
  # file written before they were kept leaves its scores' unknown.
  def test_each_last_score_keeps_its_class_and_older_ones_are_unknown
    old = LifetimeStats.parse("games=2\nrecent=3,9\n")
    stats = add(add(old, game(score: 4)), game(score: 6), size_class: DotPopper::SizeClass::FITTED)

    assert_equal [3, 9, 4, 6], stats.recent
    assert_equal [nil, nil, MEDIUM, DotPopper::SizeClass::FITTED], stats.recent_classes
    assert_includes stats.to_text, "recent_classes=?,?,medium,fitted\n"
    assert_equal stats.recent_classes, LifetimeStats.parse(stats.to_text).recent_classes
  end

  def test_the_last_scores_classes_are_trimmed_with_them
    stats = LifetimeStats.new
    25.times { stats = add(stats, game(score: it), size_class: it.even? ? SMALL : MEDIUM) }

    assert_equal 20, stats.recent_classes.size
    assert_equal MEDIUM, stats.recent_classes.first
  end

  def test_a_record_is_judged_against_its_own_class_only
    stats = add(add(LifetimeStats.new, game(longest_run: 20)), game(longest_run: 4), size_class: SMALL)

    assert_equal [:longest_run], stats.records_set_by(game(longest_run: 6), SMALL).map(&:kind)
    assert_empty stats.records_set_by(game(longest_run: 6), MEDIUM).map(&:kind)
    assert_empty stats.records_set_by(game(longest_run: 60), DotPopper::SizeClass::LARGE),
                 "a class's first game has nothing to beat"
  end

  def test_a_game_with_no_pops_has_no_fastest_pop
    assert_nil add(LifetimeStats.new, game(pops: 0, waits: [])).bests_in(MEDIUM).fastest_pop
  end

  def test_only_the_last_twenty_scores_are_kept
    stats = LifetimeStats.new
    25.times { stats = add(stats, game(score: it)) }

    assert_equal (5..24).to_a, stats.recent
  end

  def test_records_are_what_a_game_beats_most_impressive_first
    before = add(LifetimeStats.new, game)
    better = game(duration: 41.0, longest_run: 9, waits: [0.4, 2.5])

    assert_equal %i[longest_run longest_game fastest_pop], before.records_set_by(better, MEDIUM).map(&:kind)
    assert_equal 9, before.records_set_by(better, MEDIUM).first.value
  end

  def test_the_first_game_sets_no_records
    assert_empty LifetimeStats.new.records_set_by(game, MEDIUM)
  end

  def test_a_tie_as_the_game_shows_it_is_not_a_record
    before = add(LifetimeStats.new, game)

    assert_empty before.records_set_by(game(duration: 30.4, waits: [0.76, 2.54]), MEDIUM)
    assert_equal [:longest_wait], before.records_set_by(game(waits: [2.56]), MEDIUM).map(&:kind)
  end

  def test_it_saves_and_reads_back
    stats = add(add(LifetimeStats.new, game, day: "2026-11-05"), game(score: 3, waits: []), day: "2026-11-05",
                size_class: SMALL)
    stats = stats.with(streak: DotPopper::GoalStreak.new(current: 2, longest: 4, last_met: "2026-11-05"))

    assert_equal stats, LifetimeStats.parse(stats.to_text)
    assert_includes stats.to_text, "small.longest_run=8\n"
    refute LifetimeStats.old?(stats.to_text)
  end

  # Before bests were kept by class, the file named them without one.
  # They go to the class the game is told is this screen's.
  def test_an_older_file_gives_its_bests_to_this_screens_class
    old = "games=7\npops=80\nlongest_game=41.5\nlongest_run=12\nfastest_pop=0.4\nlongest_wait=5.5\nrecent=3,9\n"
    stats = LifetimeStats.parse(old, legacy: SMALL)

    assert LifetimeStats.old?(old)
    assert_equal 7, stats.games
    assert_equal [3, 9], stats.recent
    assert_equal [SMALL], stats.bests.keys
    bests = stats.bests_in(SMALL)
    assert_equal [7, 41.5, 12, 0.4, 5.5],
                 [bests.games, bests.longest_game, bests.longest_run, bests.fastest_pop, bests.longest_wait]
    assert_equal stats, LifetimeStats.parse(stats.to_text)
  end

  def test_a_missing_file_reads_as_nothing_yet
    assert_equal LifetimeStats.new, LifetimeStats.parse(nil)
    assert_equal LifetimeStats.new, LifetimeStats.parse("")
    refute LifetimeStats.old?(nil)
  end

  def test_a_damaged_file_keeps_what_it_can
    stats = LifetimeStats.parse("games=7\npops=lots\nslips=-3\nmedium.games=2\nmedium.longest_wait=nan\n" \
                                "last_day=yesterday\nrecent=4,x,09,5\n\u0000garbage\nmedium.fastest_pop=0.5\n" \
                                "huge.games=3\n")

    assert_equal 7, stats.games
    assert_equal 0, stats.pops
    assert_equal 0, stats.slips
    assert_in_delta 0.0, stats.bests_in(MEDIUM).longest_wait
    assert_nil stats.last_day
    assert_equal [4, 9, 5], stats.recent
    assert_in_delta 0.5, stats.bests_in(MEDIUM).fastest_pop
    assert_equal [MEDIUM], stats.bests.keys
  end
end
