# frozen_string_literal: true

require_relative "presentation_helper"

class LayoutTest < Minitest::Test
  include PresentationTest

  def test_the_window_opens_at_the_reference_play_area
    assert_equal [1200, 800], Look::WINDOW.size_for(3000, 2000, R)
  end

  def test_the_window_fits_a_small_desktop_keeping_its_shape
    width, height = Look::WINDOW.size_for(1280, 720, R)

    assert_operator height, :<=, 720 * 0.9
    assert_operator width, :<=, 1280 * 0.9
    assert_in_delta 1.5, width.to_f / height, 0.01
  end

  def test_the_mute_button_sits_in_the_safe_area_and_fits_a_finger
    safe = Rect.new(x: 40, y: 20, width: 700, height: 500)
    button = Layout.new(width: 800, height: 600, safe:, look: Look::LAYOUT).mute_button

    assert_operator button.right, :<=, safe.right
    assert_operator button.bottom, :<=, safe.bottom
    assert_operator button.width, :>=, 44
    assert button.contains?(button.center_x, button.center_y)
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

  def test_your_records_sits_across_from_the_mute_button_in_the_safe_area
    safe = Rect.new(x: 40, y: 20, width: 320, height: 800)
    narrow = Layout.new(width: 400, height: 850, safe:, look: Look::LAYOUT)
    button = narrow.records_button

    assert_operator button.x, :>=, safe.x
    assert_operator button.bottom, :<=, safe.bottom
    assert_operator button.height, :>=, 44
    assert_operator button.reach(2 * R).right, :<, narrow.mute_button.x
  end

  # The dot-size choice, label and segments, shares the bottom row on a
  # wide window, and on an upright phone takes a row of its own above it,
  # under its label; either way it overlaps neither button, and stays in
  # the safe area.
  def test_the_dot_size_choice_finds_room_beside_or_above_the_corner_buttons
    [[1200, 800], [400, 850], [400, 320], [800, 600], [2560, 1440]].each do |width, height|
      plan = layout(width, height)
      control = plan.sizing_control
      left, right = control.options

      assert_operator left.height, :>=, 44, "#{width}x#{height}"
      assert_equal left.right, right.x, "#{width}x#{height}: the segments touch"
      [control.label, control.frame].each do |part|
        assert_operator part.x, :>=, 0, "#{width}x#{height}"
        assert_operator part.right, :<=, width, "#{width}x#{height}"
        [plan.records_button, plan.mute_button].each { assert apart?(part, it), "#{width}x#{height}" }
      end
      assert apart?(control.label, control.frame), "#{width}x#{height}"
    end
    wide = layout(1200, 800).sizing_control
    assert_equal layout(1200, 800).mute_button.y, wide.frame.y
    assert_in_delta 600, wide.frame.center_x, 0.01, "its segments are centred"
    narrow = layout(400, 850).sizing_control
    assert_operator narrow.frame.bottom, :<, layout(400, 850).mute_button.y
    assert_operator narrow.label.bottom, :<=, narrow.frame.y + 1e-9
  end

  # Whether two rects do not overlap, to within a rounding error.
  def apart?(one, other, slack = 1e-9)
    one.right <= other.x + slack || other.right <= one.x + slack || one.bottom <= other.y + slack ||
      other.bottom <= one.y + slack
  end
end
