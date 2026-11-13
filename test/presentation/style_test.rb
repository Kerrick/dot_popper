# frozen_string_literal: true

require_relative "presentation_helper"

# The limits the brief sets on effects, so a setting cannot quietly break
# one: effects that could hide dots stay small and short.
class StyleTest < Minitest::Test
  include PresentationTest

  def test_droplets_live_briefly
    assert_operator Style::POP_BURST.life.end, :<=, Burst::LONGEST_LIFE
    assert_operator Style::POP_BURST.size.end, :<=, 0.15
  end

  def test_the_shake_is_within_its_limit
    assert_operator Style::PENALTY_SHAKE.amplitude, :<=, ShakeStyle::LIMIT
    assert_operator Style::PENALTY_SHAKE.duration, :<=, 0.25
  end

  # A wrong tap's edge glow tints a dot near an edge only for a moment.
  def test_the_penalty_glow_is_soft_narrow_and_quick
    flash = Style::PENALTY_FLASH

    assert_operator flash.alpha, :<=, 0.45
    assert_operator flash.band, :<=, 0.12
    assert_operator flash.duration, :<=, 0.35
  end

  # A dot under the HUD still shows through its pill.
  def test_the_hud_is_see_through
    assert_operator Style::HUD.backing, :<=, 0.5
  end

  def test_floaters_fade_fast
    [Style::GAIN_FLOAT, Style::LOSS_FLOAT].each { assert_operator it.life, :<=, 0.8 }
  end

  def test_a_dot_settles_at_its_rule_size
    motion = Style::MOTION

    assert_in_delta 1.0, motion.spawn.to
    assert_in_delta 1.0, motion.pop_stretch.to
  end

  # What is seen of a dot at rest ends at its hit circle: the bright dot's
  # rim is inside it, and only a faint halo and a small shadow fall
  # outside, so a moving target's edge is where a tap reaches it.
  def test_a_dot_at_rest_ends_at_its_hit_circle
    dot = Style::DOT

    assert_operator dot.rim, :<, 0.1
    assert_operator dot.halo(1.0), :<=, 0.2
    assert_operator dot.halo(1.06), :<, 0.02
    assert_operator dot.halo(1.15), :<, 0.5 / 255
    assert_operator dot.shadow_reach, :<=, 1.1
    assert_operator dot.shadow_edge, :<=, 1.16
    assert_operator dot.shadow_alpha, :<=, 0.45
    assert_operator dot.extent, :<=, 1.3
  end

  # The glow is off: bright enough to see, it blurs the bright dot's edge.
  def test_nothing_blooms_around_the_bright_dot
    assert_predicate Style::BLOOM.strength, :zero?
  end

  def test_the_window_is_a_tablet_sized_play_area
    assert_equal [24, 16], [Style::WINDOW.width, Style::WINDOW.height]
  end

  def test_the_settings_are_frozen_values
    [Style::PALETTE, Style::TYPE, Style::MOTION, Style::HUD, Style::GAME_OVER, Style::WORDS].each { assert_predicate it, :frozen? }
  end
end
