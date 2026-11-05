# frozen_string_literal: true

require_relative "presentation_helper"

class EffectsTest < Minitest::Test
  include PresentationTest

  def setup = @effects = Effects.new(radius: R, random: Random.new(1), particle_capacity: 40)

  def test_droplets_never_outnumber_the_pool
    10.times { @effects.burst(0, 0, Look::POP_BURST, Look::PALETTE.confetti) }

    assert_equal 40, @effects.particles.count
  end

  def test_droplets_are_gone_within_their_longest_life
    @effects.burst(0, 0, Look::POP_BURST.with(life: 5.0..6.0), Look::PALETTE.confetti)
    @effects.update(Burst::LONGEST_LIFE + 0.01)

    assert_equal 0, @effects.particles.count
  end

  def test_a_droplet_fades_and_shrinks_as_it_goes
    particle = Particle.new.launch(x: 0, y: 0, velocity_x: 10, velocity_y: 0, life: 0.4, size: 4, color: nil,
                                   drag: 0, gravity: 0, alpha: 0.8)
    particle.update(0.2)

    assert_operator particle.alpha, :<, 0.8
    assert_operator particle.size, :<, 4
    assert_in_delta 2.0, particle.x
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

    assert_operator floater.height(later), :<, 200
    assert_operator floater.alpha(later), :<, floater.alpha(@effects.now)
  end

  def test_floaters_and_rings_are_capped
    50.times { @effects.float("+1", 0, 0, Look::PALETTE.cream, Look::GAIN_FLOAT) }

    assert_equal Effects::MOST_FLOATERS, @effects.floaters.size
  end
end
