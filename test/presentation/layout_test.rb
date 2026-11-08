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

  # "How to play" stands beside the mute button, between it and "Your
  # records", where there is room for it, and otherwise, as on a small
  # upright phone, on a row of its own above the mute button, with the
  # dot-size choice above that. It is never smaller than a fingertip, and
  # never wider than the safe area.
  def test_how_to_play_sits_beside_the_mute_button_or_a_row_above_it
    [[1200, 800], [400, 850], [375, 812], [320, 568], [400, 320], [812, 375], [2560, 1440]].each do |width, height|
      plan = layout(width, height)
      button = plan.how_to_play_button
      name = "#{width}x#{height}"

      assert_operator button.height, :>=, 44, name
      assert_operator button.width, :>=, button.height * Layout::HOW_TO_PLAY_LEAST, name
      assert_operator button.x, :>=, 0, name
      assert_operator button.right, :<=, width, name
      [plan.records_button, plan.mute_button, plan.sizing_control.label, plan.sizing_control.frame].each do
        assert apart?(button, it), "#{name}: #{button.to_h} overlaps #{it.to_h}"
      end
    end
    wide = layout(1200, 800)
    assert_equal wide.mute_button.y, wide.how_to_play_button.y, "beside the mute button"
    assert_operator wide.how_to_play_button.right, :<, wide.mute_button.x
    assert_operator wide.sizing_control.frame.right, :<, wide.how_to_play_button.x, "the dot-size choice still fits"
    small = layout(375, 812)
    assert_operator small.how_to_play_button.bottom, :<, small.mute_button.y, "a row above it"
    assert_operator small.sizing_control.frame.bottom, :<, small.how_to_play_button.y
  end

  # A desktop's "Full screen" and Quit: a row of their own above the
  # bottom row's right end, Quit in the corner over the mute button, as
  # tall as the other buttons, apart from them, and with the dot-size
  # choice, where it has no room in the bottom row, a row above them; or
  # their icons alone, a fingertip across, in the top right corner.
  def test_full_screen_and_quit_take_a_row_above_the_corner_buttons_or_the_top_corner
    [[1200, 800], [800, 500], [400, 320], [2560, 1440]].each do |width, height|
      plan = layout(width, height)
      buttons = plan.window_buttons
      above = plan.sizing_control(above: buttons.rects)
      name = "#{width}x#{height}"

      assert buttons.labelled
      assert_in_delta plan.mute_button.right, buttons.quit.right, 1e-9, name
      assert_operator buttons.quit.bottom, :<, plan.mute_button.y, name
      assert_operator buttons.fullscreen.x, :>=, plan.margin, name
      [plan.how_to_play_button, plan.mute_button, plan.records_button, above.label, above.frame].each do |other|
        buttons.rects.each { assert apart?(it, other), "#{name}: #{it.to_h} overlaps #{other.to_h}" }
      end
      next if above.frame.y == plan.mute_button.y

      assert_operator above.frame.bottom, :<, buttons.quit.y, "#{name}: the stacked choice stands above them"
    end
    icons = layout(400, 320).window_icons
    refute icons.labelled
    assert_equal [44.0, 44.0], [icons.quit.width, icons.quit.height]
    assert_in_delta layout(400, 320).mute_button.right, icons.quit.right, 1e-9
    assert_in_delta layout(400, 320).top, icons.quit.y, 1e-9
    assert apart?(icons.fullscreen, icons.quit)
  end

  # Whether two rects do not overlap, to within a rounding error.
  def apart?(one, other, slack = 1e-9)
    one.right <= other.x + slack || other.right <= one.x + slack || one.bottom <= other.y + slack ||
      other.bottom <= one.y + slack
  end
end
