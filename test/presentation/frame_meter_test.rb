# frozen_string_literal: true

require_relative "presentation_helper"

class FrameMeterTest < Minitest::Test
  FrameMeter = DotPopper::Presentation::FrameMeter

  def test_it_reports_once_a_stretch_has_passed
    meter = FrameMeter.start(1)
    reports = []
    59.times do
      meter, report = meter.record(1 / 60.0)
      reports << report
    end
    meter, report = meter.record(1 / 60.0)

    assert_equal [nil], reports.uniq
    assert_equal "60 frames a second, longest frame 16.7 ms (last 1 s)", report
    assert_equal 0, meter.frames, "a new stretch starts"
  end

  def test_the_longest_frame_is_the_real_one_even_past_the_rules_cap
    meter = FrameMeter.start(1)
    meter, = meter.record(0.25)
    _, report = meter.record(0.8)

    assert_match(/longest frame 800\.0 ms/, report)
  end
end
