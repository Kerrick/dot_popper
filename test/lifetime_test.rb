# frozen_string_literal: true

require "test_helper"

class LifetimeTest < Minitest::Test
  Lifetime = DotPopper::Lifetime
  RoundStats = DotPopper::RoundStats
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def setup
    @store = DotPopper::BestScore::Memory.new
    @lifetime = Lifetime.new(@store, today: -> { Date.new(2026, 11, 5) })
  end

  def test_a_round_is_added_and_saved_on_todays_date
    @lifetime.record(RoundStats.start.with(score: 4, pops: 4, duration: 14.0), MEDIUM)

    saved = Lifetime.new(@store).stats
    assert_equal 1, saved.rounds
    assert_equal "2026-11-05", saved.last_day
    assert_equal [4], saved.recent
  end

  def test_it_returns_the_records_a_round_set
    @lifetime.record(RoundStats.start.with(longest_run: 3, duration: 10.0), MEDIUM)

    assert_equal %i[longest_run longest_round],
                 @lifetime.record(RoundStats.start.with(longest_run: 5, duration: 20.0), MEDIUM).records.map(&:kind)
  end

  # 2026-11-03's goal is to score 30 points in one round.
  def test_the_first_round_to_meet_todays_goal_says_so_and_adds_a_day_to_the_streak
    day = Date.new(2026, 11, 3)
    lifetime = Lifetime.new(@store, today: -> { day })
    assert_equal :score, lifetime.goal.kind

    refute lifetime.record(RoundStats.start.with(score: 29), MEDIUM).goal_met
    refute lifetime.goal_done?
    assert lifetime.record(RoundStats.start.with(score: 30), MEDIUM).goal_met
    assert lifetime.goal_done?
    refute lifetime.record(RoundStats.start.with(score: 35), MEDIUM).goal_met, "it is met only once a day"
    assert_equal 1, lifetime.streak
    assert_equal 1, Lifetime.new(@store, today: -> { day }).streak, "the streak is saved"
  end

  def test_the_streak_counts_days_in_a_row_and_a_missed_day_starts_it_again
    days = { Date.new(2026, 11, 3) => :score, Date.new(2026, 11, 8) => :score, Date.new(2026, 11, 12) => :score }
    days.each_key do |day|
      Lifetime.new(@store, today: -> { day }).record(RoundStats.start.with(score: 30), MEDIUM)
    end
    later = Lifetime.new(@store, today: -> { Date.new(2026, 11, 13) })

    assert_equal 1, later.streak
    assert_equal 1, later.stats.streak.longest
  end

  def test_an_older_file_is_given_to_this_screens_class_and_saved_again_at_once
    store = DotPopper::BestScore::Memory.new("rounds=3\nlongest_round=20.0\nlongest_run=5\n")
    small = DotPopper::SizeClass::SMALL
    lifetime = Lifetime.new(store, legacy: small)

    assert_equal 5, lifetime.stats.bests_in(small).longest_run
    assert_includes store.read, "small.longest_run=5\n"
    assert_equal 5, Lifetime.new(store, legacy: MEDIUM).stats.bests_in(small).longest_run
  end

  def test_a_store_holding_nonsense_starts_from_nothing
    assert_equal DotPopper::LifetimeStats.new, Lifetime.new(DotPopper::BestScore::Memory.new("\xFF\xFE".b)).stats
  end
end
