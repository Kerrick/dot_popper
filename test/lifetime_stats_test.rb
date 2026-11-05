# frozen_string_literal: true

require "test_helper"

class LifetimeStatsTest < Minitest::Test
  LifetimeStats = DotPopper::LifetimeStats
  RoundStats = DotPopper::RoundStats

  def round(score: 10, pops: 12, slips: 1, duration: 30.0, longest_run: 8, waits: [0.8, 2.5, 1.2])
    RoundStats.start.with(score:, pops:, slips:, duration:, longest_run:, waits:)
  end

  def test_a_round_adds_to_the_totals_and_the_bests
    stats = LifetimeStats.new.add(round, day: "2026-11-05")

    assert_equal [1, 12, 1, 1, "2026-11-05"], [stats.rounds, stats.pops, stats.slips, stats.days, stats.last_day]
    assert_in_delta 30.0, stats.seconds
    assert_in_delta 30.0, stats.longest_round
    assert_equal 8, stats.longest_run
    assert_in_delta 0.8, stats.fastest_pop
    assert_in_delta 2.5, stats.longest_wait
    assert_equal [10], stats.recent
  end

  def test_a_day_counts_once_however_many_rounds_it_has
    stats = LifetimeStats.new
    %w[2026-11-05 2026-11-05 2026-11-06].each { stats = stats.add(round, day: it) }

    assert_equal 2, stats.days
    assert_equal 3, stats.rounds
  end

  def test_bests_keep_the_better_of_old_and_new
    stats = LifetimeStats.new.add(round, day: "d").add(round(duration: 12.0, longest_run: 3, waits: [4.0]), day: "d")

    assert_in_delta 30.0, stats.longest_round
    assert_equal 8, stats.longest_run
    assert_in_delta 0.8, stats.fastest_pop
    assert_in_delta 4.0, stats.longest_wait
  end

  def test_a_round_with_no_pops_has_no_fastest_pop
    assert_nil LifetimeStats.new.add(round(pops: 0, waits: []), day: "d").fastest_pop
  end

  def test_only_the_last_twenty_scores_are_kept
    stats = LifetimeStats.new
    25.times { stats = stats.add(round(score: it), day: "d") }

    assert_equal (5..24).to_a, stats.recent
  end

  def test_records_are_what_a_round_beats_most_impressive_first
    before = LifetimeStats.new.add(round, day: "d")
    better = round(duration: 41.0, longest_run: 9, waits: [0.4, 2.5])

    assert_equal %i[longest_run longest_round fastest_pop], before.records_set_by(better).map(&:kind)
    assert_equal 9, before.records_set_by(better).first.value
  end

  def test_the_first_round_sets_no_records
    assert_empty LifetimeStats.new.records_set_by(round)
  end

  def test_a_tie_as_the_game_shows_it_is_not_a_record
    before = LifetimeStats.new.add(round, day: "d")

    assert_empty before.records_set_by(round(duration: 30.4, waits: [0.76, 2.54]))
    assert_equal [:longest_wait], before.records_set_by(round(waits: [2.56])).map(&:kind)
  end

  def test_it_saves_and_reads_back
    stats = LifetimeStats.new.add(round, day: "2026-11-05").add(round(score: 3, waits: []), day: "2026-11-05")
    stats = stats.with(streak: DotPopper::GoalStreak.new(current: 2, longest: 4, last_met: "2026-11-05"))

    assert_equal stats, LifetimeStats.parse(stats.to_text)
  end

  def test_a_missing_file_reads_as_nothing_yet
    assert_equal LifetimeStats.new, LifetimeStats.parse(nil)
    assert_equal LifetimeStats.new, LifetimeStats.parse("")
  end

  def test_a_damaged_file_keeps_what_it_can
    stats = LifetimeStats.parse("rounds=7\npops=lots\nslips=-3\nlongest_wait=nan\nlast_day=yesterday\n" \
                                "recent=4,x,09,5\n\u0000garbage\nfastest_pop=0.5")

    assert_equal 7, stats.rounds
    assert_equal 0, stats.pops
    assert_equal 0, stats.slips
    assert_in_delta 0.0, stats.longest_wait
    assert_nil stats.last_day
    assert_equal [4, 9, 5], stats.recent
    assert_in_delta 0.5, stats.fastest_pop
  end
end
