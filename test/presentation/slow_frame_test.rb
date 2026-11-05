# frozen_string_literal: true

require_relative "presentation_helper"

class SlowFrameTest < Minitest::Test
  SlowFrame = DotPopper::Presentation::SlowFrame

  def test_only_a_frame_of_fifty_milliseconds_or_more_is_slow
    refute SlowFrame.slow?(0.049)
    assert SlowFrame.slow?(0.05)
  end

  def test_it_says_where_it_happened_what_came_before_and_what_collected
    frame = SlowFrame.new(seconds: 0.5355, screen: "Game Over", recent: "RoundEnded", since: 0.02, major_gcs: 1,
                          minor_gcs: 0)

    assert_equal "slow frame 535.5 ms on Game Over; 0.0 s after RoundEnded; garbage collections: 1 major, 0 minor",
                 frame.report
  end

  def test_with_nothing_recent_it_leaves_that_part_out
    frame = SlowFrame.new(seconds: 0.06, screen: "a round", recent: nil, since: nil, major_gcs: 0, minor_gcs: 2)

    assert_equal "slow frame 60.0 ms on a round; garbage collections: 0 major, 2 minor", frame.report
  end
end
