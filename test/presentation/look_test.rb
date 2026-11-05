# frozen_string_literal: true

require_relative "presentation_helper"

# The limits the brief sets on effects, so a setting cannot quietly break
# one: effects that could hide dots stay small and short.
class LookTest < Minitest::Test
  include PresentationTest

  def test_droplets_live_briefly
    assert_operator Look::POP_BURST.life.end, :<=, Burst::LONGEST_LIFE
    assert_operator Look::POP_BURST.size.end, :<=, 0.15
  end

  def test_the_shake_is_within_its_limit
    assert_operator Look::PENALTY_SHAKE.amplitude, :<=, ShakeLook::LIMIT
    assert_operator Look::PENALTY_SHAKE.duration, :<=, 0.25
  end

  # A wrong tap's edge glow tints a dot near an edge only for a moment.
  def test_the_penalty_glow_is_soft_narrow_and_quick
    flash = Look::PENALTY_FLASH

    assert_operator flash.alpha, :<=, 0.45
    assert_operator flash.band, :<=, 0.12
    assert_operator flash.duration, :<=, 0.35
  end

  # A dot under the HUD still shows through its pill.
  def test_the_hud_is_see_through
    assert_operator Look::HUD.backing, :<=, 0.5
  end

  def test_floaters_fade_fast
    [Look::GAIN_FLOAT, Look::LOSS_FLOAT].each { assert_operator it.life, :<=, 0.8 }
  end

  def test_a_dot_settles_at_its_rule_size
    motion = Look::MOTION

    assert_in_delta 1.0, motion.spawn.to
    assert_in_delta 1.0, motion.pop_stretch.to
    assert_operator motion.breathe.amplitude, :<=, 0.03
  end

  def test_the_window_is_a_tablet_sized_play_area
    assert_equal [24, 16], [Look::WINDOW.width, Look::WINDOW.height]
  end

  def test_the_settings_are_frozen_values
    [Look::PALETTE, Look::TYPE, Look::MOTION, Look::HUD, Look::FINALE, Look::WORDS].each { assert_predicate it, :frozen? }
  end
end
