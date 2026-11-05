# frozen_string_literal: true

require "test_helper"

class CountdownTest < Minitest::Test
  def test_it_counts_down_and_shows_whole_seconds_rounded_down
    clock = DotPopper::Countdown.new(10).tick(0.25)

    assert_in_delta 9.75, clock.remaining
    assert_equal 9, clock.whole_seconds
  end

  def test_it_never_goes_below_zero
    clock = DotPopper::Countdown.new(1).tick(5)

    assert_equal 0.0, clock.remaining
    assert_equal 0, clock.whole_seconds
    assert clock.expired?
  end

  def test_a_penalty_can_empty_it
    clock = DotPopper::Countdown.new(1.5).adjust(-2)

    assert clock.expired?
    assert_equal 0, clock.whole_seconds
  end

  def test_a_reward_adds_time
    clock = DotPopper::Countdown.new(3.5).adjust(1)

    assert_in_delta 4.5, clock.remaining
  end
end
