# frozen_string_literal: true

require "test_helper"

class LifetimeTest < Minitest::Test
  Lifetime = DotPopper::Lifetime
  RoundStats = DotPopper::RoundStats

  def setup
    @store = DotPopper::BestScore::Memory.new
    @lifetime = Lifetime.new(@store, today: -> { Date.new(2026, 11, 5) })
  end

  def test_a_round_is_added_and_saved_on_todays_date
    @lifetime.record(RoundStats.start.with(score: 4, pops: 4, duration: 14.0))

    saved = Lifetime.new(@store).stats
    assert_equal 1, saved.rounds
    assert_equal "2026-11-05", saved.last_day
    assert_equal [4], saved.recent
  end

  def test_it_returns_the_records_a_round_set
    @lifetime.record(RoundStats.start.with(longest_run: 3, duration: 10.0))

    assert_equal %i[longest_run longest_round],
                 @lifetime.record(RoundStats.start.with(longest_run: 5, duration: 20.0)).map(&:kind)
  end

  def test_a_store_holding_nonsense_starts_from_nothing
    assert_equal DotPopper::LifetimeStats.new, Lifetime.new(DotPopper::BestScore::Memory.new("\xFF\xFE".b)).stats
  end
end
