# frozen_string_literal: true

require "test_helper"

# Thousands of random games on random fields, each a random run of taps,
# clock ticks, and resizes or turns of the window, checking after every step what must always be true of
# the rules. A failure names the seed that found it; RULES_FUZZ_SEED
# replays one.
class RulesFuzzTest < Minitest::Test
  include DotPopperTest

  ROUNDS = 2_000
  STEPS = 40
  EPSILON = 1e-9

  def test_random_play_keeps_every_rule
    seed = Integer(ENV.fetch("RULES_FUZZ_SEED", 20_261_105))
    random = Random.new(seed)
    ROUNDS.times { |number| play(random, "seed #{seed}, game #{number}") }
  end

  # Title, Playing, Game Over, and back, in random order and timing.
  # Outside Playing, nothing changes the score or the clock.
  def test_random_presses_change_a_game_only_while_it_is_played
    seed = Integer(ENV.fetch("RULES_FUZZ_SEED", 20_261_105))
    random = Random.new(seed)
    cabinet = DotPopper::Cabinet.new(random_field(random), random:)
    seen = Set.new
    3_000.times do |step|
      before = cabinet.state
      seen << before.class
      kept = [cabinet.game&.score, cabinet.game&.countdown]
      random.rand < 0.5 ? cabinet.press(*aim_anywhere(cabinet, random)) : cabinet.update(random.rand(1.5))
      next if before.is_a?(DotPopper::Cabinet::Playing)

      assert_equal kept, [before.game&.score, before.game&.countdown], "seed #{seed}, step #{step}"
    end
    assert_equal 3, seen.size, "seed #{seed} never reached every state"
  end

  private

  def aim_anywhere(cabinet, random) = [random.rand(cabinet.field.width), random.rand(cabinet.field.height)]

  def play(random, where)
    game = DotPopper::Game.new(random_field(random), random:)
    check_spawn(game, [], where)
    check_game(game, where)
    STEPS.times do
      break if game.over?

      case random.rand
      when ...0.6 then tap(game, random, where)
      when ...0.93 then tick(game, random, where)
      else resize(game, random, where)
      end
      check_game(game, where)
    end
  end

  # From a sliver narrower than a dot to a large monitor.
  def random_field(random) = DotPopper::Field.new(random.rand(40.0..3000.0), random.rand(40.0..1800.0), R)

  # Most taps aim at a dot, popped or bright, so they often land where dots
  # overlap; the rest land anywhere.
  def tap(game, random, where)
    x, y = aim(game, random)
    before = game.dots.to_a
    score = game.score
    remaining = game.countdown.remaining
    event = game.tap_at(x, y)
    check_tap(event, before, x, y, game, where)
    check_score_change(event, game.score - score, score, where)
    check_clock_change(event, game.countdown.remaining - remaining, remaining, where)
  end

  def aim(game, random)
    if random.rand < 0.8
      target = game.dots.to_a.sample(random:)
      angle = random.rand(2 * Math::PI)
      reach = random.rand(1.3) * target.radius
      [target.x + (reach * Math.cos(angle)), target.y + (reach * Math.sin(angle))]
    else
      [random.rand(game.field.width), random.rand(game.field.height)]
    end
  end

  def tick(game, random, where)
    ids = game.dots.map(&:id)
    remaining = game.countdown.remaining
    seconds = random.rand < 0.1 ? random.rand(20.0) : random.rand(0.2)
    game.update(seconds)

    assert_equal ids, game.dots.map(&:id), "#{where}: a tick changed the dots"
    assert_in_delta [remaining - seconds, 0].max, game.countdown.remaining, EPSILON, "#{where}: the clock"
  end

  # A resize, or half the time a phone's turn, keeps every dot, its order,
  # whether it is popped, and its velocity, and moves each in proportion
  # across the field's room, and it touches neither score nor clock.
  def resize(game, random, where)
    old = game.field
    before = game.dots.to_a
    kept = [game.score, game.countdown]
    game.field = random.rand < 0.5 ? DotPopper::Field.new(old.height, old.width, old.radius) : random_field(random)
    after = game.dots.to_a

    assert_equal kept, [game.score, game.countdown], "#{where}: a resize changed the score or clock"
    assert_equal before.map { [it.id, it.popped?, it.velocity_x, it.velocity_y] },
                 after.map { [it.id, it.popped?, it.velocity_x, it.velocity_y] }, "#{where}: a resize changed a dot"
    before.zip(after).each { |was, now| check_proportion(was, now, old, game.field, where) }
  end

  def check_proportion(was, now, old, new, where)
    [[was.x, now.x, old.min_x, old.max_x, new.min_x, new.max_x],
     [was.y, now.y, old.min_y, old.max_y, new.min_y, new.max_y]].each do |from, to, low, high, new_low, new_high|
      next unless high > low && new_high > new_low

      assert_in_delta (from - low) / (high - low), (to - new_low) / (new_high - new_low), 1e-6,
                      "#{where}: dot #{was.id} moved out of proportion"
    end
  end

  def check_game(game, where)
    field = game.field
    game.dots.each do |dot|
      assert dot.x.between?(field.min_x - EPSILON, field.max_x + EPSILON), "#{where}: dot #{dot.id} left the field"
      assert dot.y.between?(field.min_y - EPSILON, field.max_y + EPSILON), "#{where}: dot #{dot.id} left the field"
    end
    assert_operator game.score, :>=, DotPopper::Rules::LOWEST_SCORE, "#{where}: score below zero"
    assert_operator game.countdown.remaining, :>=, 0, "#{where}: negative clock"
    assert_equal 1, game.dots.count(&:bright?), "#{where}: not exactly one bright dot" unless game.over?
    ids = game.dots.map(&:id)
    assert_equal ids.sort, ids, "#{where}: a newer dot is above an older one"
  end

  # The tap reached the topmost dot under the point and changed no other.
  def check_tap(event, before, x, y, game, where)
    top = before.find { Math.hypot(x - it.x, y - it.y) <= it.radius }
    after = game.dots.to_a
    case event
    in DotPopper::Events::Missed
      assert_nil top, "#{where}: a tap on a dot missed"
      assert_equal before, after, "#{where}: a miss changed the dots"
    in DotPopper::Events::Popped(dot:, spawned:)
      assert_equal top&.id, dot.id, "#{where}: a pop reached past the top dot"
      assert top.bright?, "#{where}: a popped dot was popped again"
      assert_equal before.map { it.id == dot.id ? it.pop : it } + [spawned], after, "#{where}: a pop changed more"
      check_spawn(game, after[0...-1], where)
    in DotPopper::Events::Penalized(dot:)
      assert_equal top&.id, dot.id, "#{where}: a penalty reached past the top dot"
      assert top.popped?, "#{where}: a bright dot cost a penalty"
      assert_equal before, after, "#{where}: a penalty changed the dots"
    end
  end

  # The game's newest dot, spawned under +above+, has a touch target
  # within the lookahead, or every try to give it one failed.
  def check_spawn(game, above, where)
    spawn = game.spawns.last
    assert_equal game.dots.to_a.last, spawn.dot, "#{where}: the spawn is not the newest dot"
    if spawn.exhausted?
      tries = DotPopper::Rules::SPAWN_TRIES
      assert_equal [tries, tries], [spawn.velocity_redraws, spawn.position_redraws], "#{where}: gave up too soon"
    else
      assert DotPopper::SpawnCheck.for(game.field).exposed_soon?(spawn.dot, above), "#{where}: a spawn stayed hidden"
    end
  end

  # A pop earns one point; a mistake loses two, or as many as are left.
  def check_score_change(event, change, score, where)
    expected = case event
               in DotPopper::Events::Popped then DotPopper::Rules::POP_POINTS
               in DotPopper::Events::Penalized then -[DotPopper::Rules::PENALTY_POINTS, score].min
               in DotPopper::Events::Missed then 0
               end
    assert_equal expected, change, "#{where}: the score changed by #{change}"
    assert_equal expected, event.points, "#{where}: the event misreports the points" unless expected.zero?
  end

  def check_clock_change(event, change, remaining, where)
    expected = case event
               in DotPopper::Events::Popped then DotPopper::Rules::POP_SECONDS
               in DotPopper::Events::Penalized then -[DotPopper::Rules::PENALTY_SECONDS, remaining].min
               in DotPopper::Events::Missed then 0
               end
    assert_in_delta expected, change, EPSILON, "#{where}: the clock changed by #{change}"
  end
end
