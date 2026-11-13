# frozen_string_literal: true

require "test_helper"

class DotSizeTest < Minitest::Test
  def test_a_desktop_dot_is_fifty_units
    size = DotPopper::DotSize.for(DotPopper::Platform::COMPUTER, unit: "logical pixels")

    assert_equal 50, size.radius
    assert_equal "50 logical pixels", size.reason
  end

  def test_a_touch_dot_falls_back_to_fifty_units_for_about_eight_millimeters
    size = DotPopper::DotSize.for(DotPopper::Platform::PHONE, unit: "points")

    assert_equal 50, size.radius
    assert_equal "50 points, about 8 mm", size.reason
  end

  def test_it_makes_a_field_with_its_radius
    assert_equal DotPopper::Field.new(800, 600, 50), DotPopper::DotSize.for(DotPopper::Platform::COMPUTER, unit: "units").field(800, 600)
  end
end

class StandardDotSizeTest < Minitest::Test
  def standard(width, height) = DotPopper::DotSize.standard(width, height).radius

  def test_the_reference_window_keeps_the_usual_radius
    assert_in_delta 50.0, standard(1200, 800)
  end

  def test_a_big_monitor_gets_bigger_dots_for_the_same_room
    radius = standard(3010, 1690)

    assert_in_delta 115.1, radius, 0.1
    assert_in_delta 384, 3010 * 1690 / (radius**2), 0.5
  end

  # 395 by 850 points is an upright iPhone. Its exact fit, 29.6, would
  # be under the smallest radius, so the dot stays 60 points across.
  def test_a_phone_gets_smaller_dots_but_never_below_a_comfortable_target
    assert_in_delta 30.0, standard(395, 850)
    assert_in_delta 30.0, standard(400, 320)
    assert_operator 2 * DotPopper::Rules::SMALLEST_STANDARD_RADIUS, :>, 44
  end

  def test_a_long_thin_window_keeps_a_dot_a_dot
    assert_in_delta 400 / 7.0, standard(5000, 400)
  end

  def test_it_says_what_it_chose
    assert_match(/standard for the screen/, DotPopper::DotSize.standard(1200, 800).reason)
  end
end
