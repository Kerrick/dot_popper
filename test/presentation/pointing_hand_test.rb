# frozen_string_literal: true

require_relative "presentation_helper"

class PointingHandTest < Minitest::Test
  include PresentationTest

  HAND = DotPopper::Presentation::PointingHand

  def test_its_fingertip_is_on_the_point_it_taps
    finger = HAND::PARTS[1].first
    assert_in_delta 0.0, finger.x + (finger.width / 2.0), 1e-9, "the finger is centred on it"
    assert finger.y.negative? && finger.y > -finger.width, "its pad, not its middle, is on it"
  end

  # Tilted, the hand reaches down and to the right from its tip, and only
  # its fingertip is above or left of it, so it hides no more of the dot
  # it taps than a fingertip would.
  def test_it_reaches_in_from_below_and_to_the_right
    left, top, right, bottom = HAND::BOUNDS
    assert_operator left, :>, -1.0
    assert_operator top, :>, -1.0
    assert_operator right, :>, 3.0
    assert_operator bottom, :>, 4.0
  end

  def test_it_turns_away_from_an_edge_that_would_cut_it_off
    unit = 10.0
    assert_equal [1, 1], HAND.facing(100, 100, unit, 400, 850), "from below and to the right"
    assert_equal [-1, 1], HAND.facing(380, 100, unit, 400, 850), "from the left, near the right edge"
    assert_equal [1, -1], HAND.facing(100, 830, unit, 400, 850), "from above, near the bottom"
    assert_equal [-1, -1], HAND.facing(380, 830, unit, 400, 850), "from above and to the left, in the corner"
  end
end
