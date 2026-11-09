# frozen_string_literal: true

require "test_helper"

class SpawnerTest < Minitest::Test
  include DotPopperTest

  SEED = 3

  def spawner(on = field) = DotPopper::Spawner.for(on)
  def check(on = field) = DotPopper::SpawnCheck.for(on)

  # What the spec's rule alone would draw from a Random seeded with SEED.
  def plain_draw(on = field) = DotPopper::Dot.spawn(on, Random.new(SEED), id: 9)

  def popped_on(fresh, **changes) = fresh.with(id: 1, popped: true, **changes)

  def test_a_fresh_dot_with_room_for_a_target_now_is_kept_and_draws_nothing_more
    random = Random.new(SEED)
    reference = Random.new(SEED)
    expected = DotPopper::Dot.spawn(field, reference, id: 9)

    spawn = spawner.spawn(random, id: 9, above: [dot(-500, -500, popped: true)])

    assert_equal expected, spawn.dot
    refute spawn.redrawn?
    refute spawn.moved?
    assert_equal reference.rand, random.rand, "the same randomness is left over"
  end

  def test_a_fresh_dot_hidden_under_a_popped_dot_moving_with_it_gets_a_new_velocity
    hidden = plain_draw
    above = [popped_on(hidden)]
    refute check.exposed_soon?(hidden, above), "the two would move as one"

    spawn = spawner.spawn(Random.new(SEED), id: 9, above:)

    assert spawn.redrawn?
    refute spawn.moved?
    assert_equal [hidden.x, hidden.y], [spawn.dot.x, spawn.dot.y], "its place stays as drawn"
    assert check.exposed_soon?(spawn.dot, above)
  end

  def test_a_fresh_dot_covered_now_but_drifting_out_within_the_second_is_kept
    covered = plain_draw
    above = [popped_on(covered, velocity_x: -covered.velocity_x, velocity_y: -covered.velocity_y)]
    refute DotPopper::TouchTarget.on(R).clear_on?(covered.x, covered.y, above), "covered at first"

    spawn = spawner.spawn(Random.new(SEED), id: 9, above:)

    assert_equal covered, spawn.dot
    refute spawn.redrawn?
  end

  # A target's centre must be 44 from a dot above's at R 50. The popped
  # dot leaving at 120 a second gets there in about a third of a second.
  # The one by the edge would get there at 60 a second, but it bounces
  # 10 units on and comes back, so it is never more than 40 away.
  def test_the_lookahead_games_the_dots_forward_with_their_bounces
    leaving = dot(400, 300, velocity_x: 120, popped: true)
    bouncing = dot(740, 300, velocity_x: 60, popped: true)

    assert check.exposed_soon?(dot(400, 300), [leaving])
    refute check.exposed_soon?(dot(740, 300), [bouncing])
  end

  def test_a_field_packed_solid_still_spawns_after_every_try
    small = field(300, 300)
    packed = (0..15).flat_map { |row| (0..15).map { |column| dot(column * 20, row * 20, popped: true) } }

    spawn = spawner(small).spawn(Random.new(SEED), id: 9, above: packed)

    assert spawn.exhausted?
    assert_equal [DotPopper::Rules::SPAWN_TRIES] * 2, [spawn.velocity_redraws, spawn.position_redraws]
    assert spawn.dot.fresh?
    assert_equal 9, spawn.dot.id
  end

  def test_with_no_tries_every_draw_stands
    hidden = plain_draw

    spawn = DotPopper::Spawner.for(field, tries: 0).spawn(Random.new(SEED), id: 9, above: [popped_on(hidden)])

    assert_equal hidden, spawn.dot
    assert spawn.exhausted?
  end

  def test_a_dot_too_small_for_a_target_is_never_redrawn
    tiny = DotPopper::Field.new(800, 600, 20)
    hidden = plain_draw(tiny)

    spawn = spawner(tiny).spawn(Random.new(SEED), id: 9, above: [popped_on(hidden)])

    assert_equal hidden, spawn.dot
    refute spawn.exhausted?
  end

  def test_a_game_stats_how_each_dot_was_spawned
    game = DotPopper::Game.new(field, random: Random.new(SEED))
    first = game.dots.first

    assert_equal [first], game.spawns.map(&:dot)
    assert_equal plain_draw.with(id: 0), first, "the game's first dot is drawn as ever"
    game.tap_at(first.x, first.y)
    assert_equal game.dots.to_a.last, game.spawns.last.dot
  end
end
