# frozen_string_literal: true

require_relative "presentation_helper"

class PixelsTest < Minitest::Test
  include PresentationTest

  def test_snapping_moves_to_the_nearest_device_pixel
    retina = Pixels.new(scale: 2)

    assert_in_delta 10.5, retina.snap(10.3)
    assert_in_delta 10.0, retina.snap(10.2)
    assert_in_delta 10.0, Pixels.new(scale: 1).snap(10.4)
  end

  def test_snapping_works_at_fractional_scales
    pixels = Pixels.new(scale: 1.5)
    snapped = pixels.snap(10.0)

    assert_in_delta (snapped * 1.5).round, snapped * 1.5, 1e-9
  end

  def test_a_line_is_a_whole_number_of_device_pixels
    assert_in_delta 0.5, Pixels.new(scale: 2).line_width(1)
    assert_in_delta 1.0, Pixels.new(scale: 2).line_width(2)
    assert_in_delta 0.5, Pixels.new(scale: 2).line_width(0)
  end

  def test_an_odd_width_line_sits_on_a_pixel_centre
    retina = Pixels.new(scale: 2)

    assert_in_delta 10.25, retina.line_at(10.1, 1)
    assert_in_delta 10.0, retina.line_at(10.1, 2)
  end

  def test_a_size_in_whole_device_pixels_is_never_zero
    assert_in_delta 0.5, Pixels.new(scale: 2).whole(0.1)
    assert_in_delta 2.5, Pixels.new(scale: 2).whole(2.4)
  end

  def test_a_scale_that_is_not_positive_counts_as_one
    assert_in_delta 1.0, Pixels.new(scale: 0).scale
  end

  def test_an_animated_font_size_steps
    assert_equal 40, Pixels.font_size(40.9, step: 2)
    assert_equal 42, Pixels.font_size(41.2, step: 2)
    assert_equal 1, Pixels.font_size(0.1)
  end
end
