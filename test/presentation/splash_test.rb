# frozen_string_literal: true

require_relative "presentation_helper"

class SplashTest < Minitest::Test
  include PresentationTest

  def test_it_fades_in_holds_and_fades_out_in_about_one_and_a_half_seconds
    assert_in_delta 1.4, Splash::TOTAL, 0.05
    splash = Splash.start
    assert_equal [0.0, 1.0], [splash.mark, splash.ground]
    assert_in_delta 0.5, splash.advance(Splash::FADE_IN / 2).mark, 1e-9
    held = splash.advance(Splash::FADE_IN + 0.3)
    assert_equal [1.0, 1.0], [held.mark, held.ground]
    middle = splash.advance(Splash::TOTAL - (Splash::FADE_OUT / 2))
    assert_in_delta 0.5, middle.mark, 1e-9
    assert_in_delta 0.5, middle.ground, 1e-9
  end

  def test_it_is_over_after_its_total_time_and_a_skip_ends_it
    refute_predicate Splash.start.advance(Splash::TOTAL - 0.01), :over?
    assert_predicate Splash.start.advance(Splash::TOTAL), :over?
    assert_predicate Splash.start.skip, :over?
    assert_equal 0.0, Splash.start.skip.mark
  end

  def test_the_bot_the_director_and_a_request_leave_it_out
    refute Splash.skipped?({})
    refute Splash.skipped?("DOT_POPPER_NO_SPLASH" => "")
    %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_SPLASH].each { assert Splash.skipped?({ it => "1" }) }
  end

  def test_the_logotype_is_centred_and_keeps_setdefs_proportions
    mark = Logotype.new(size: 100)
    left = mark.left(600)
    assert_in_delta 600, left + (mark.width / 2.0), 1e-9
    assert_equal %w[s e t d e f], mark.letters(left).map(&:first)
    block_left, block_width = mark.block(left)
    assert_in_delta 1.03 / 1.78, block_width / mark.block_height, 1e-9
    assert_operator block_left, :>, mark.letters(left).last.last
    baseline = mark.baseline(400)
    assert_in_delta 400, mark.block_top(baseline) + (mark.block_height / 2.0), 1e-9
    assert_in_delta 1.57 * 0.52 * 100, baseline - mark.block_top(baseline), 1e-9
  end

  def test_it_is_sized_in_whole_units_to_the_window_and_fits_a_phone
    wide = Logotype.fit(1200, 800)
    assert_kind_of Integer, wide.size
    assert_in_delta 0.78, wide.width / 1200, 0.01
    assert_operator Logotype.fit(400, 850).width, :<=, 400 * 0.7
    assert_operator Logotype.fit(1200, 300).block_height, :<=, 300 * 0.6
  end
end
