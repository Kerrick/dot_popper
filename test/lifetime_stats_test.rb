# frozen_string_literal: true

require "test_helper"

class LifetimeStatsTest < Minitest::Test
  LifetimeStats = DotPopper::LifetimeStats
  RoundStats = DotPopper::RoundStats
  SMALL = DotPopper::SizeClass::SMALL
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def round(score: 10, pops: 12, slips: 1, duration: 30.0, longest_run: 8, waits: [0.8, 2.5, 1.2])
    RoundStats.start.with(score:, pops:, slips:, duration:, longest_run:, waits:)
  end

  def add(stats, round, day: "d", size_class: MEDIUM) = stats.add(round, day:, size_class:)

  def test_a_round_adds_to_the_totals_and_the_bests
    stats = add(LifetimeStats.new, round, day: "2026-11-05")
    bests = stats.bests_in(MEDIUM)

    assert_equal [1, 12, 1, 1, "2026-11-05"], [stats.rounds, stats.pops, stats.slips, stats.days, stats.last_day]
    assert_in_delta 30.0, stats.seconds
    assert_equal 1, bests.rounds
    assert_in_delta 30.0, bests.longest_round
    assert_equal 8, bests.longest_run
    assert_in_delta 0.8, bests.fastest_pop
    assert_in_delta 2.5, bests.longest_wait
    assert_equal [10], stats.recent
  end

  def test_a_day_counts_once_however_many_rounds_it_has
    stats = LifetimeStats.new
    %w[2026-11-05 2026-11-05 2026-11-06].each { stats = add(stats, round, day: it) }

    assert_equal 2, stats.days
    assert_equal 3, stats.rounds
  end

  def test_bests_keep_the_better_of_old_and_new
    stats = add(add(LifetimeStats.new, round), round(duration: 12.0, longest_run: 3, waits: [4.0]))
    bests = stats.bests_in(MEDIUM)

    assert_in_delta 30.0, bests.longest_round
    assert_equal 8, bests.longest_run
    assert_in_delta 0.8, bests.fastest_pop
    assert_in_delta 4.0, bests.longest_wait
  end

  # A phone's crowded field and a big monitor's roomy one are different
  # contests, so each class of screen keeps bests of its own; the totals
  # and the last scores take in every round.
  def test_each_class_of_screen_keeps_its_own_bests_and_shares_the_totals
    stats = add(add(LifetimeStats.new, round(longest_run: 20, score: 30)), round(longest_run: 4, score: 5),
                size_class: SMALL)

    assert_equal 20, stats.bests_in(MEDIUM).longest_run
    assert_equal 4, stats.bests_in(SMALL).longest_run
    assert_equal 1, stats.bests_in(SMALL).rounds
    assert_equal 0, stats.bests_in(DotPopper::SizeClass::LARGE).rounds
    assert_equal 2, stats.rounds
    assert_equal [30, 5], stats.recent
  end

  def test_a_record_is_judged_against_its_own_class_only
    stats = add(add(LifetimeStats.new, round(longest_run: 20)), round(longest_run: 4), size_class: SMALL)

    assert_equal [:longest_run], stats.records_set_by(round(longest_run: 6), SMALL).map(&:kind)
    assert_empty stats.records_set_by(round(longest_run: 6), MEDIUM).map(&:kind)
    assert_empty stats.records_set_by(round(longest_run: 60), DotPopper::SizeClass::LARGE),
                 "a class's first round has nothing to beat"
  end

  def test_a_round_with_no_pops_has_no_fastest_pop
    assert_nil add(LifetimeStats.new, round(pops: 0, waits: [])).bests_in(MEDIUM).fastest_pop
  end

  def test_only_the_last_twenty_scores_are_kept
    stats = LifetimeStats.new
    25.times { stats = add(stats, round(score: it)) }

    assert_equal (5..24).to_a, stats.recent
  end

  def test_records_are_what_a_round_beats_most_impressive_first
    before = add(LifetimeStats.new, round)
    better = round(duration: 41.0, longest_run: 9, waits: [0.4, 2.5])

    assert_equal %i[longest_run longest_round fastest_pop], before.records_set_by(better, MEDIUM).map(&:kind)
    assert_equal 9, before.records_set_by(better, MEDIUM).first.value
  end

  def test_the_first_round_sets_no_records
    assert_empty LifetimeStats.new.records_set_by(round, MEDIUM)
  end

  def test_a_tie_as_the_game_shows_it_is_not_a_record
    before = add(LifetimeStats.new, round)

    assert_empty before.records_set_by(round(duration: 30.4, waits: [0.76, 2.54]), MEDIUM)
    assert_equal [:longest_wait], before.records_set_by(round(waits: [2.56]), MEDIUM).map(&:kind)
  end

  def test_it_saves_and_reads_back
    stats = add(add(LifetimeStats.new, round, day: "2026-11-05"), round(score: 3, waits: []), day: "2026-11-05",
                size_class: SMALL)
    stats = stats.with(streak: DotPopper::GoalStreak.new(current: 2, longest: 4, last_met: "2026-11-05"))

    assert_equal stats, LifetimeStats.parse(stats.to_text)
    assert_includes stats.to_text, "small.longest_run=8\n"
    refute LifetimeStats.old?(stats.to_text)
  end

  # Before bests were kept by class, the file named them without one.
  # They go to the class the game is told is this screen's.
  def test_an_older_file_gives_its_bests_to_this_screens_class
    old = "rounds=7\npops=80\nlongest_round=41.5\nlongest_run=12\nfastest_pop=0.4\nlongest_wait=5.5\nrecent=3,9\n"
    stats = LifetimeStats.parse(old, legacy: SMALL)

    assert LifetimeStats.old?(old)
    assert_equal 7, stats.rounds
    assert_equal [3, 9], stats.recent
    assert_equal [SMALL], stats.bests.keys
    bests = stats.bests_in(SMALL)
    assert_equal [7, 41.5, 12, 0.4, 5.5],
                 [bests.rounds, bests.longest_round, bests.longest_run, bests.fastest_pop, bests.longest_wait]
    assert_equal stats, LifetimeStats.parse(stats.to_text)
  end

  def test_a_missing_file_reads_as_nothing_yet
    assert_equal LifetimeStats.new, LifetimeStats.parse(nil)
    assert_equal LifetimeStats.new, LifetimeStats.parse("")
    refute LifetimeStats.old?(nil)
  end

  def test_a_damaged_file_keeps_what_it_can
    stats = LifetimeStats.parse("rounds=7\npops=lots\nslips=-3\nmedium.rounds=2\nmedium.longest_wait=nan\n" \
                                "last_day=yesterday\nrecent=4,x,09,5\n\u0000garbage\nmedium.fastest_pop=0.5\n" \
                                "huge.rounds=3\n")

    assert_equal 7, stats.rounds
    assert_equal 0, stats.pops
    assert_equal 0, stats.slips
    assert_in_delta 0.0, stats.bests_in(MEDIUM).longest_wait
    assert_nil stats.last_day
    assert_equal [4, 9, 5], stats.recent
    assert_in_delta 0.5, stats.bests_in(MEDIUM).fastest_pop
    assert_equal [MEDIUM], stats.bests.keys
  end
end
