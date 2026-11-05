# frozen_string_literal: true

require "test_helper"

# Thousands of random rounds on random fields, each a random run of taps
# and clock ticks, checking after every step what must always be true of
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
    ROUNDS.times { |number| play(random, "seed #{seed}, round #{number}") }
  end

  # Title, Playing, Game Over, and back, in random order and timing.
  # Outside Playing, nothing changes the score or the clock.
  def test_random_presses_change_a_round_only_while_it_is_played
    seed = Integer(ENV.fetch("RULES_FUZZ_SEED", 20_261_105))
    random = Random.new(seed)
    game = DotPopper::Game.new(random_field(random), random:)
    seen = Set.new
    3_000.times do |step|
      before = game.state
      seen << before.class
      kept = [game.round&.score, game.round&.countdown]
      random.rand < 0.5 ? game.press(*aim_anywhere(game, random)) : game.update(random.rand(1.5))
      next if before.is_a?(DotPopper::Game::Playing)

      assert_equal kept, [before.round&.score, before.round&.countdown], "seed #{seed}, step #{step}"
    end
    assert_equal 3, seen.size, "seed #{seed} never reached every state"
  end

  private

  def aim_anywhere(game, random) = [random.rand(game.field.width), random.rand(game.field.height)]

  def play(random, where)
    round = DotPopper::Round.new(random_field(random), random:)
    check_round(round, where)
    STEPS.times do
      break if round.over?

      random.rand < 0.6 ? tap(round, random, where) : tick(round, random, where)
      check_round(round, where)
    end
  end

  # From a sliver narrower than a dot to a large monitor.
  def random_field(random) = DotPopper::Field.new(random.rand(40.0..3000.0), random.rand(40.0..1800.0), R)

  # Most taps aim at a dot, popped or fresh, so they often land where dots
  # overlap; the rest land anywhere.
  def tap(round, random, where)
    x, y = aim(round, random)
    before = round.dots.to_a
    score = round.score
    remaining = round.countdown.remaining
    event = round.tap_at(x, y)
    check_tap(event, before, x, y, round, where)
    check_score_change(event, round.score - score, score, where)
    check_clock_change(event, round.countdown.remaining - remaining, remaining, where)
  end

  def aim(round, random)
    if random.rand < 0.8
      target = round.dots.to_a.sample(random:)
      angle = random.rand(2 * Math::PI)
      reach = random.rand(1.3) * target.radius
      [target.x + (reach * Math.cos(angle)), target.y + (reach * Math.sin(angle))]
    else
      [random.rand(round.field.width), random.rand(round.field.height)]
    end
  end

  def tick(round, random, where)
    ids = round.dots.map(&:id)
    remaining = round.countdown.remaining
    seconds = random.rand < 0.1 ? random.rand(20.0) : random.rand(0.2)
    round.update(seconds)

    assert_equal ids, round.dots.map(&:id), "#{where}: a tick changed the dots"
    assert_in_delta [remaining - seconds, 0].max, round.countdown.remaining, EPSILON, "#{where}: the clock"
  end

  def check_round(round, where)
    field = round.field
    round.dots.each do |dot|
      assert dot.x.between?(field.min_x - EPSILON, field.max_x + EPSILON), "#{where}: dot #{dot.id} left the field"
      assert dot.y.between?(field.min_y - EPSILON, field.max_y + EPSILON), "#{where}: dot #{dot.id} left the field"
    end
    assert_operator round.score, :>=, DotPopper::Rules::LOWEST_SCORE, "#{where}: score below zero"
    assert_operator round.countdown.remaining, :>=, 0, "#{where}: negative clock"
    assert_equal 1, round.dots.count(&:fresh?), "#{where}: not exactly one fresh dot" unless round.over?
    ids = round.dots.map(&:id)
    assert_equal ids.sort, ids, "#{where}: a newer dot is above an older one"
  end

  # The tap reached the topmost dot under the point and changed no other.
  def check_tap(event, before, x, y, round, where)
    top = before.find { Math.hypot(x - it.x, y - it.y) <= it.radius }
    after = round.dots.to_a
    case event
    in DotPopper::Events::Missed
      assert_nil top, "#{where}: a tap on a dot missed"
      assert_equal before, after, "#{where}: a miss changed the dots"
    in DotPopper::Events::Popped(dot:, spawned:)
      assert_equal top&.id, dot.id, "#{where}: a pop reached past the top dot"
      assert top.fresh?, "#{where}: a popped dot was popped again"
      assert_equal before.map { it.id == dot.id ? it.pop : it } + [spawned], after, "#{where}: a pop changed more"
    in DotPopper::Events::Penalized(dot:)
      assert_equal top&.id, dot.id, "#{where}: a penalty reached past the top dot"
      assert top.popped?, "#{where}: a fresh dot cost a penalty"
      assert_equal before, after, "#{where}: a penalty changed the dots"
    end
  end

  # A pop earns one point; a wrong tap loses two, or as many as are left.
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
