# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"

module DotPopperTest
  R = DotPopper::Rules::RADIUS

  def field(width = 800, height = 600) = DotPopper::Field.new(width, height, R)

  def dot(x, y, velocity_x: 0, velocity_y: 0, popped: false, id: (@ids = (@ids || 100) + 1))
    DotPopper::Dot.new(id:, x:, y:, velocity_x:, velocity_y:, radius: R, popped:)
  end

  # A round whose dots are exactly the ones given, top first, in place of
  # the one it would spawn.
  def round_with(*dots, random: Random.new(1))
    DotPopper::Round.new(field, random:, dots: DotPopper::Stack.new(dots:))
  end

  # Sets a round's score as if earlier taps had earned it.
  def score!(round, points) = round.instance_variable_set(:@score, points)

  # Moves every dot of the round but +keep+ far out of the way.
  def clear_around!(round, keep)
    moved = round.dots.map_dots { it.id == keep.id ? it : it.with(x: -1000.0) }
    round.instance_variable_set(:@dots, moved)
  end
end
