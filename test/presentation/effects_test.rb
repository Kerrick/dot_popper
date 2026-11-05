# frozen_string_literal: true

require_relative "presentation_helper"

class EffectsTest < Minitest::Test
  include PresentationTest

  def setup = @effects = Effects.new(radius: R, random: Random.new(1))

  def test_a_burst_waits_for_the_shell_to_throw_it
    @effects.burst(10, 20, Look::POP_BURST, Look::PALETTE.confetti)
    sprays = @effects.take_sprays

    assert_equal [[10, 20]], sprays.map { [it.x, it.y] }
    assert_empty @effects.take_sprays
  end

  def test_a_pop_never_outlives_the_longest_life
    @effects.burst(0, 0, Look::POP_BURST.with(life: 5.0..6.0), Look::PALETTE.confetti)

    assert_operator @effects.take_sprays.first.longest, :<=, Burst::LONGEST_LIFE
  end

  def test_waiting_bursts_are_capped
    50.times { @effects.burst(0, 0, Look::POP_BURST, Look::PALETTE.confetti) }

    assert_equal Effects::MOST_SPRAYS, @effects.take_sprays.size
  end

  def test_a_clear_drops_waiting_bursts_and_says_so
    @effects.burst(0, 0, Look::POP_BURST, Look::PALETTE.confetti)
    @effects.clear

    assert_empty @effects.take_sprays
    assert_equal 1, @effects.cleared
  end

  def test_every_droplet_of_a_burst_gets_a_color
    colors = Look::PALETTE.confetti
    shares = Look::POP_BURST.shares(colors, Random.new(4))

    assert_equal Look::POP_BURST.count, shares.values.sum
    assert_equal colors.size, shares.size
    assert_operator shares.values.minmax.then { |least, most| most - least }, :<=, 1
  end

  def test_the_shake_is_small_and_short
    @effects.kick(Look::PENALTY_SHAKE)
    offsets = (0..30).map do
      @effects.update(0.01)
      Math.hypot(@effects.shake_x, @effects.shake_y)
    end

    assert_operator offsets.max, :<=, ShakeLook::LIMIT * R * Math.sqrt(2)
    assert_operator offsets.max, :>, 0
    assert_in_delta 0.0, offsets.last
  end

  def test_a_calm_shake_never_moves
    calm = Effects.new(radius: R, calm: true)
    calm.kick(Look::PENALTY_SHAKE)
    calm.update(0.03)

    assert_in_delta 0.0, calm.shake_x
  end

  def test_the_edge_flash_fades_out
    @effects.light(Look::PENALTY_FLASH)
    bright = @effects.flash_alpha
    @effects.update(Look::PENALTY_FLASH.duration)

    assert_in_delta Look::PENALTY_FLASH.alpha, bright
    assert_in_delta 0.0, @effects.flash_alpha
  end

  def test_rings_and_floaters_go_away_when_done
    @effects.ring(0, 0, Look::SHOCKWAVE)
    @effects.float("+1", 0, 0, Look::PALETTE.cream, Look::GAIN_FLOAT)
    @effects.update(1.0)

    assert_empty @effects.rings
    assert_empty @effects.floaters
  end

  def test_a_ring_around_a_dot_moves_with_it
    ring = @effects.ring(0, 0, Look::SPAWN_RIPPLE, follow: 7)

    assert_equal [300.0, 40.0], ring.center([dot(300, 40, id: 7)])
    assert_equal [0, 0], ring.center([])
  end

  def test_a_floater_rises_and_fades
    floater = @effects.float("+1", 100, 200, Look::PALETTE.cream, Look::GAIN_FLOAT)
    later = @effects.now + Look::GAIN_FLOAT.life * 0.9

    assert_operator floater.y_at(later), :<, 200
    assert_operator floater.alpha(later), :<, floater.alpha(@effects.now)
  end

  def test_floaters_and_rings_are_capped
    50.times { @effects.float("+1", 0, 0, Look::PALETTE.cream, Look::GAIN_FLOAT) }

    assert_equal Effects::MOST_FLOATERS, @effects.floaters.size
  end
end
