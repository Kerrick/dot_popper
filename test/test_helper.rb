# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"

module DotPopperTest
  R = DotPopper::Rules::RADIUS

  def field(width = 800, height = 600) = DotPopper::Field.new(width, height, R)

  def dot(x, y, velocity_x: 0, velocity_y: 0, popped: false)
    DotPopper::Dot.new(x:, y:, velocity_x:, velocity_y:, radius: R).tap { it.pop if popped }
  end

  # A round whose dots are exactly the ones given, top first, in place of
  # the one it spawned.
  def round_with(*dots, random: Random.new(1))
    DotPopper::Round.new(field, random:).tap do |round|
      stack = DotPopper::Stack.new
      dots.each { stack.slide_under(it) }
      round.instance_variable_set(:@dots, stack)
    end
  end
end
