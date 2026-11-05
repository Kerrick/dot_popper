# frozen_string_literal: true

require "test_helper"

class DotSizeTest < Minitest::Test
  def test_a_desktop_dot_is_fifty_logical_pixels
    size = DotPopper::DotSize.for("Windows")

    assert_equal 50, size.radius
    assert_match(/logical pixels/, size.reason)
  end

  def test_a_touch_dot_falls_back_to_fifty_points_for_about_eight_millimetres
    assert_equal 50, DotPopper::DotSize.for("iOS").radius
    assert_match(/points, about 8 mm/, DotPopper::DotSize.for("iOS").reason)
    assert_match(/dp/, DotPopper::DotSize.for("Android").reason)
  end

  def test_it_makes_a_field_with_its_radius
    assert_equal DotPopper::Field.new(800, 600, 50), DotPopper::DotSize.for("OS X").field(800, 600)
  end
end
