# frozen_string_literal: true

require_relative "presentation_helper"

class ColorTest < Minitest::Test
  include PresentationTest

  def palette = Look::PALETTE

  def test_hex_reads_each_channel
    color = Color.hex("#ff8000", 0.5)

    assert_equal [1.0, 128 / 255.0, 0.0, 0.5], color.to_a
    assert_equal [255, 128, 0, 128], color.bytes
  end

  def test_mixing_goes_part_of_the_way
    mixed = Color.hex("#000000").mix(Color.hex("#ffffff"), 0.25)

    assert_in_delta 0.25, mixed.r
  end

  def test_luminance_runs_from_black_to_white
    assert_in_delta 0.0, Color.hex("#000000").luminance
    assert_in_delta 1.0, Color.hex("#ffffff").luminance
    assert_in_delta 21.0, Color.hex("#000000").contrast(Color.hex("#ffffff")), 0.01
  end

  # Fresh and popped dots must differ in lightness, so they read apart in
  # grayscale and for red-green colorblind players, not only by hue.
  def test_every_fresh_color_is_far_lighter_than_every_popped_color
    fresh = [palette.fresh_light, palette.fresh_body, palette.fresh_deep, palette.fresh_bounce]
    popped = [palette.popped_top, palette.popped_bottom, palette.popped_crater]

    fresh.product(popped).each { |light, dark| assert_operator light.contrast(dark), :>=, 2.5 }
    assert_operator palette.fresh_body.contrast(palette.popped_lip), :>=, 3.0
    assert_operator palette.fresh_body.contrast(palette.popped_top), :>=, 4.5
  end

  def test_a_fresh_dot_stands_out_from_the_night
    assert_operator palette.fresh_body.contrast(palette.ink_top), :>=, 7.0
  end

  def test_a_popped_dot_still_shows_against_the_night_by_its_rim
    assert_operator palette.popped_rim.contrast(palette.ink_top), :>=, 3.0
    assert_operator palette.popped_top.luminance, :>, palette.ink_top.luminance
  end

  def test_the_words_read_on_the_night
    [palette.cream, palette.soft, palette.gain, palette.alarm, palette.urgent].each do |color|
      assert_operator color.contrast(palette.ink_bottom), :>=, 4.5
    end
  end
end
