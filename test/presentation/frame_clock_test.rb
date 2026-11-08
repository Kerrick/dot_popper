# frozen_string_literal: true

require_relative "presentation_helper"

class FrameClockTest < Minitest::Test
  FrameClock = DotPopper::Presentation::FrameClock

  def test_the_first_move_takes_lotas_time
    _, seconds = FrameClock.start.tick(10.0, 0.016)

    assert_in_delta 0.016, seconds
  end

  # Lota measured 7.5 ms, then 25 ms, at the loop's top; the frames
  # started to draw 16.7 ms apart.
  def test_it_moves_by_the_time_between_frames_starting_to_draw
    clock, = FrameClock.start.tick(0.0, 0.016)
    clock = clock.drawing(0.001)
    clock, = clock.tick(0.0085, 0.0075)
    clock = clock.drawing(0.0177)
    clock, seconds = clock.tick(0.0335, 0.025)

    assert_in_delta 0.0167, seconds
    _, seconds = clock.drawing(0.0344).tick(0.041, 0.0075)

    assert_in_delta 0.0167, seconds
  end

  def test_with_nothing_drawn_it_counts_up_to_now
    clock, = FrameClock.start.tick(0.0, 0.016)
    clock, seconds = clock.tick(0.25, 0.25)

    assert_in_delta 0.25, seconds
    _, seconds = clock.tick(0.5, 0.25)

    assert_in_delta 0.25, seconds
  end

  def test_every_second_is_counted_once
    clock, = FrameClock.start.tick(0.0, 0.0)
    total = 0.0
    now = 0.0
    [0.0075, 0.025, 0.003, 0.03, 0.2, 0.0167].each_with_index do |gap, i|
      clock = clock.drawing(now + 0.002) unless i == 4 # the app was away for one
      now += gap
      clock, seconds = clock.tick(now, gap)
      total += seconds
    end

    assert_in_delta clock.counted, total, 1e-9, "counted up to the last frame's start"
    assert_in_delta now - 0.0167 + 0.002, total, 1e-9
  end

  def test_it_never_moves_back
    clock, = FrameClock.start.tick(1.0, 0.016)
    _, seconds = clock.drawing(0.5).tick(1.01, 0.01)

    assert_in_delta 0.0, seconds
  end
end
