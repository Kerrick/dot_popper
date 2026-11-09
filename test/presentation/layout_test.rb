# frozen_string_literal: true

require_relative "presentation_helper"

class LayoutTest < Minitest::Test
  include PresentationTest

  def test_the_window_opens_at_the_reference_play_area
    assert_equal [1200, 800], Style::WINDOW.size_for(3000, 2000, R)
  end

  def test_the_window_fits_a_small_desktop_keeping_its_shape
    width, height = Style::WINDOW.size_for(1280, 720, R)

    assert_operator height, :<=, 720 * 0.9
    assert_operator width, :<=, 1280 * 0.9
    assert_in_delta 1.5, width.to_f / height, 0.01
  end

  # On the maintainer's PC, Windows at 200% counts the window in pixels:
  # a 400 by 320 window was 200 by 160 units, too small for Home's
  # buttons. The window and its smallest size are the same in units on
  # every display.
  def test_a_display_counting_pixels_gets_the_same_window_in_units
    smallest = [400, 320]
    assert_equal [1200, 800, 400, 320], Style::WINDOW.mode_for(3000, 2000, R, per_unit: 1.0, smallest:)
    assert_equal [2400, 1600, 800, 640], Style::WINDOW.mode_for(6000, 4000, R, per_unit: 2.0, smallest:)
    assert_equal [800, 1700, 800, 640], Style::WINDOW.mode_for(6000, 4000, R, per_unit: 2.0, smallest:, wanted: [400, 850])
  end

  def test_text_scales_with_the_screen_within_bounds
    assert_in_delta 0.72, layout(300, 200).ui
    assert_in_delta 1.35, layout(4000, 3000).ui
    assert_equal 40, layout(1200, 760).scaled(40)
  end

  def test_a_rect_knows_its_edges
    rect = Rect.new(x: 10, y: 20, width: 30, height: 40)

    assert_equal [40, 60], [rect.right, rect.bottom]
    refute rect.contains?(41, 30)
    assert_equal 12, rect.inset(2).x
  end

  # Whether two rects do not overlap, to within a rounding error.
  def apart?(one, other, slack = 1e-9)
    one.right <= other.x + slack || other.right <= one.x + slack || one.bottom <= other.y + slack ||
      other.bottom <= one.y + slack
  end
end
