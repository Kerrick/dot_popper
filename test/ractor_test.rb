# frozen_string_literal: true

require "test_helper"

# The rules' values are deeply frozen, so any Ractor may read them
# without a copy, and a whole round can be played in a Ractor of its own,
# as script/simulate.rb does.
class RactorTest < Minitest::Test
  include DotPopperTest

  def test_the_rules_values_can_be_shared_between_ractors
    stack = DotPopper::Stack.new(dots: [dot(100, 100), dot(200, 200, popped: true)])
    values = [field, stack, stack.dots.first, DotPopper::Countdown.new(remaining: 3),
              DotPopper::DotSize.for("iOS"), DotPopper::DotSize.fitted(395, 850), DotPopper::DotSizing::SIZED_TO_SCREEN,
              DotPopper::SizeClass::FITTED, DotPopper::Events::Missed.new(x: 1, y: 2),
              DotPopper::Events::Popped.new(dot: stack.dots.first.pop, x: 1, y: 2, points: 1, seconds: 1.0,
                                            spawned: stack.dots.last),
              DotPopper::Events::Penalized.new(dot: stack.dots.last, x: 1, y: 2, points: -2, seconds: -2.0)]

    values.each { assert Ractor.shareable?(it), "#{it.class} is not shareable" }
  end

  def test_the_rule_numbers_can_be_read_from_any_ractor
    DotPopper::Rules.constants.each { assert Ractor.shareable?(DotPopper::Rules.const_get(it)), it }
    assert Ractor.shareable?(DotPopper::DotSize::TOUCH_SYSTEMS)
  end

  def test_a_round_played_in_a_ractor_matches_one_played_here
    here = RactorTest.play_a_round(field)

    assert_equal here, played_in_a_ractor(field)
    assert_operator here.first, :>, 0
  end

  # Taps the centre of the fresh dot every half second, from a seeded
  # Random, and answers the score and the dots' final places.
  def self.play_a_round(field)
    round = DotPopper::Round.new(field, random: Random.new(7))
    until round.over?
      round.update(0.5)
      fresh = round.dots.find(&:fresh?)
      round.tap_at(fresh.x, fresh.y) unless round.over?
    end
    [round.score, round.dots.map { [it.x, it.y, it.popped?] }]
  end

  private

  def played_in_a_ractor(field)
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    Ractor.new(field) { RactorTest.play_a_round(it) }.value
  ensure
    Warning[:experimental] = experimental
  end
end
