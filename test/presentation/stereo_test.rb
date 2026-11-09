# frozen_string_literal: true

require_relative "presentation_helper"

class StereoTest < Minitest::Test
  include PresentationTest

  def stereo = Style::SOUND.stereo

  def test_a_sound_leans_toward_its_side_of_the_screen
    assert_in_delta(-0.6, stereo.pan(0, 800))
    assert_in_delta 0.0, stereo.pan(400, 800)
    assert_in_delta 0.6, stereo.pan(800, 800)
  end

  def test_a_sound_off_the_screen_leans_no_further
    assert_in_delta 0.6, stereo.pan(5000, 800)
    assert_in_delta 0.0, stereo.pan(10, 0)
  end

  def test_a_panned_source_stays_one_unit_from_the_listener
    [-0.6, 0.0, 0.35, 1.0].each do |pan|
      x, y, z = Stereo.position(pan)

      assert_in_delta 1.0, Math.sqrt((x**2) + (y**2) + (z**2))
      assert_in_delta pan, x
      assert_operator z, :<=, 0.0
    end
  end
end
