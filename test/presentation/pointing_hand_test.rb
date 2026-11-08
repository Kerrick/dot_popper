# frozen_string_literal: true

require_relative "presentation_helper"

class PointingHandTest < Minitest::Test
  include PresentationTest

  HAND = DotPopper::Presentation::PointingHand
  ROOT = File.expand_path("../..", __dir__)

  def test_every_size_has_its_png_and_each_is_that_many_pixels_square
    HAND::SIZES.each do |size|
      path = File.join(ROOT, "assets", "emoji", "hand-#{size}.png")
      assert File.file?(path), "#{path} (ruby script/make_hand.rb)"
      assert_equal [size, size], File.binread(path, 24).unpack("@16N2"), path
    end
  end

  def test_the_smallest_png_with_enough_pixels_is_drawn_smaller_never_larger
    assert_equal 48, HAND.size_for(20)
    assert_equal 128, HAND.size_for(96.5)
    assert_equal 128, HAND.size_for(128)
    assert_equal 512, HAND.size_for(900), "past the largest, the largest"
  end

  # The fingertip is at the top, a little left of the middle, and the
  # wrist at the bottom, below and right of it, so the hand hides only
  # the lower part of the dot it taps.
  def test_its_tip_is_at_the_top_and_its_wrist_at_the_bottom
    tip_x, tip_y = HAND::TIP_AT
    wrist_x, wrist_y = HAND::WRIST_AT
    assert_operator tip_y, :<, 0.06
    assert_operator wrist_y, :>, 0.95
    assert tip_x.between?(0.35, 0.45) && wrist_x > tip_x
  end

  def test_it_mirrors_only_where_the_right_edge_would_cut_it_off
    assert_equal 1, HAND.facing(100, 150, 400)
    assert_equal(-1, HAND.facing(350, 150, 400))
  end
end
