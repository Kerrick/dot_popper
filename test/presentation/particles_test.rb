# frozen_string_literal: true

require_relative "presentation_helper"

# A Burst as LÖVE's ParticleSystem settings, and the sprites drawn for it.
class ParticlesTest < Minitest::Test
  include PresentationTest

  def emission(style = Style::POP_BURST, longest: Burst::LONGEST_LIFE, sprite_size: 16.0)
    Emission.new(style:, longest:, radius: R, sprite_size:)
  end

  def test_no_droplet_outlives_its_longest
    assert_operator emission(Style::POP_BURST.with(life: 0.3..2.0)).stats_book.max, :<=, Burst::LONGEST_LIFE
  end

  def test_speeds_and_gravity_are_in_graphics_units
    assert_in_delta Style::POP_BURST.speed.end * R, emission.speed.last
    assert_equal [0.0, Style::POP_BURST.gravity * R], emission.acceleration.last(2).then { [0.0, it.last] }
  end

  def test_the_largest_droplet_is_its_sized_radius_and_shrinks
    start, finish = emission.sizes

    assert_in_delta Style::POP_BURST.size.end * R * 2, start * 16.0
    assert_operator finish, :<, start
  end

  def test_the_smallest_droplet_starts_at_its_least_size
    style = Style::POP_BURST
    start, finish = emission.sizes
    smallest = start + (emission.size_variation * (finish - start))

    assert_in_delta style.size.begin * R * 2, smallest * 16.0, 0.01
  end

  def test_a_droplet_fades_out_from_its_burst_opacity
    alphas = emission.colors(Style::PALETTE.cream).map(&:last)

    assert_in_delta Style::POP_BURST.alpha, alphas.first
    assert_in_delta 0.0, alphas.last
    assert_equal alphas.sort.reverse, alphas
  end

  def test_a_droplet_sprite_is_soft_and_game
    assert_in_delta 1.0, SpriteArt.droplet(0, 0)
    assert_in_delta 0.0, SpriteArt.droplet(1, 0)
    assert_in_delta SpriteArt.droplet(0.5, 0), SpriteArt.droplet(0, 0.5)
  end

  def test_a_twinkle_has_rays_so_its_spin_shows
    assert_operator SpriteArt.twinkle(0.7, 0), :>, SpriteArt.twinkle(0.5, 0.5) + 0.2
    assert_in_delta 0.0, SpriteArt.twinkle(1, 1)
  end

  def test_sprite_pixels_are_sampled_at_their_centres
    assert_operator SpriteArt.alpha(:droplet, 15, 15, 32), :>, 0.99
    assert_in_delta 0.0, SpriteArt.alpha(:droplet, 0, 0, 32)
  end

  def test_fireworks_twinkle_and_spin
    sparkles = Style::GAME_OVER.sparkles

    assert_equal :twinkle, sparkles.sprite
    refute_equal 0.0, sparkles.spin.end
  end
end
