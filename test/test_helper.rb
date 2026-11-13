# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"
require "dot_popper/shell/platforms"

# The suite is an automated run: it reaches no outside host (Automation).
ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!

module DotPopperTest
  R = DotPopper::Rules::RADIUS

  # The Platform the shell makes on the system Lota::System.os calls
  # +name+, such as "iOS" or "OS X".
  def self.platform(name) = DotPopper::Shell::Platforms.for(name)

  def field(width = 800, height = 600) = DotPopper::Field.new(width, height, R)

  def dot(x, y, velocity_x: 0, velocity_y: 0, popped: false, bonus: false, id: (@ids = (@ids || 100) + 1))
    DotPopper::Dot.new(id:, x:, y:, velocity_x:, velocity_y:, radius: R, popped:, bonus:)
  end

  # A game whose dots are exactly the ones given, top first, in place of
  # the one it would spawn.
  def game_with(*dots, random: Random.new(1))
    DotPopper::Game.new(field, random:, dots: DotPopper::Stack.new(dots:))
  end

  # Sets a game's score as if earlier taps had earned it.
  def score!(game, points) = game.instance_variable_set(:@score, points)

  # Moves every dot of the game but +keep+ far out of the way.
  def clear_around!(game, keep)
    moved = game.dots.map_dots { it.id == keep.id ? it : it.with(x: -1000.0) }
    game.instance_variable_set(:@dots, moved)
  end
end
