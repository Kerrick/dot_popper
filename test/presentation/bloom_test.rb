# frozen_string_literal: true

require_relative "presentation_helper"

class BloomTest < Minitest::Test
  include PresentationTest

  def test_the_blur_neither_brightens_nor_darkens
    [1.0, 2.5, 4.0].each { assert_in_delta 1.0, BlurKernel.gaussian(it).total }
  end

  def test_the_blur_reads_between_pixels_and_fades_outward
    kernel = BlurKernel.gaussian(2.5)

    assert_in_delta 0.0, kernel.offsets.first
    assert(kernel.offsets.each_cons(2).all? { |near, far| far > near })
    assert_operator kernel.offsets[1], :>, 1.0
    assert_operator kernel.offsets[1], :<, 2.0
    assert_operator kernel.weights[2], :<, kernel.weights[1]
  end

  def test_only_the_blur_is_smaller_than_the_screen
    assert_equal [1200, 800], Look::BLOOM.blurred_size(2400, 1600)
    assert_equal [1, 1], Look::BLOOM.with(resolution: 0.001).blurred_size(10, 10)
  end

  def test_the_glow_is_gentle
    assert_operator Look::BLOOM.strength, :<=, 0.7
    assert_operator Look::BLOOM.resolution, :>=, 0.5
  end
end
