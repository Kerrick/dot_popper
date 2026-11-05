# frozen_string_literal: true

require_relative "presentation_helper"

class EaseTest < Minitest::Test
  include PresentationTest

  CURVES = %i[linear in_quad out_quad out_cubic in_out_sine out_back out_elastic].freeze

  def test_every_curve_starts_at_zero_and_ends_at_one
    CURVES.each do |curve|
      assert_in_delta 0.0, Ease.by_name(curve, 0.0), 1e-9, curve
      assert_in_delta 1.0, Ease.by_name(curve, 1.0), 1e-9, curve
    end
  end

  def test_progress_outside_the_motion_is_clamped
    CURVES.each do |curve|
      assert_in_delta 0.0, Ease.by_name(curve, -3.0), 1e-9, curve
      assert_in_delta 1.0, Ease.by_name(curve, 7.0), 1e-9, curve
    end
  end

  def test_the_bouncy_curves_overshoot_and_the_others_do_not
    samples = (1..99).map { it / 100.0 }
    assert samples.any? { Ease.out_back(it) > 1.0 }
    assert samples.any? { Ease.out_elastic(it) > 1.0 }
    %i[out_cubic in_out_sine out_quad].each { |curve| assert(samples.all? { Ease.by_name(curve, it) <= 1.0 }) }
  end

  def test_in_out_sine_is_halfway_at_the_middle
    assert_in_delta 0.5, Ease.in_out_sine(0.5), 1e-9
  end

  def test_a_tween_runs_from_its_start_to_its_end
    tween = Tween.new(from: 2.0, to: 4.0, duration: 0.5, ease: :linear)

    assert_in_delta 2.0, tween.at(0)
    assert_in_delta 3.0, tween.at(0.25)
    assert_in_delta 4.0, tween.at(9)
    refute tween.done?(0.4)
    assert tween.done?(0.5)
  end

  def test_a_tween_with_no_duration_is_already_done
    assert_in_delta 1.0, Tween.new(from: 0.0, to: 1.0, duration: 0.0).at(0.0)
  end
end
