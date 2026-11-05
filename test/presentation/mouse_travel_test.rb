# frozen_string_literal: true

require_relative "presentation_helper"

class MouseTravelTest < Minitest::Test
  MouseTravel = DotPopper::Presentation::MouseTravel

  def test_the_first_motion_only_says_where_the_pointer_is
    refute MouseTravel.start.moved(400, 300).deliberate?
  end

  def test_a_real_nudge_counts_and_a_jitter_does_not
    travel = MouseTravel.start.moved(400, 300).moved(402, 301)
    refute travel.deliberate?

    assert travel.moved(410, 301).deliberate?
  end
end
