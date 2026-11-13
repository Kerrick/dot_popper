# frozen_string_literal: true

require_relative "presentation_helper"

class ColorTest < Minitest::Test
  include PresentationTest

  def palette = Style::PALETTE

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

  # Bright and popped dots must differ in lightness, so they read apart in
  # grayscale and for red-green colorblind players, not only by hue.
  def test_every_bright_color_is_far_lighter_than_every_popped_color
    bright = [palette.bright_light, palette.bright_body, palette.bright_deep, palette.bright_bounce]
    popped = [palette.popped_top, palette.popped_bottom, palette.popped_crater]

    bright.product(popped).each { |light, dark| assert_operator light.contrast(dark), :>=, 2.5 }
    assert_operator palette.bright_body.contrast(palette.popped_lip), :>=, 3.0
    assert_operator palette.bright_body.contrast(palette.popped_top), :>=, 4.5
  end

  # The bonus dot is a bright dot first: as light as the ordinary one, so
  # it is plainly the dot to pop in grayscale too, and it is marked by a
  # shape (a dark star) that needs no hue, which must itself read on the body.
  def test_a_bonus_dot_is_as_bright_as_a_bright_one_and_its_star_reads_on_it
    bright = [palette.bonus_light, palette.bonus_body, palette.bonus_deep, palette.bonus_bounce, palette.bonus_rim]
    popped = [palette.popped_top, palette.popped_bottom, palette.popped_crater]

    bright.product(popped).each { |light, dark| assert_operator light.contrast(dark), :>=, 2.5 }
    assert_operator palette.bonus_body.contrast(palette.ink_top), :>=, 7.0
    assert_operator palette.bonus_body.contrast(palette.bonus_mark), :>=, 7.0
    assert_in_delta palette.bright_body.luminance, palette.bonus_body.luminance, 0.15
    refute_equal palette.bright_body, palette.bonus_body
  end

  def test_a_bright_dot_stands_out_from_the_night
    assert_operator palette.bright_body.contrast(palette.ink_top), :>=, 7.0
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
