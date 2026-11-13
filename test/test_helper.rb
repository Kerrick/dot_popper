# frozen_string_literal: true

require "minitest/autorun"
require "dot_popper"

# The suite is an automated run: it reaches no outside host (Automation).
ENV["DOT_POPPER_AUTOMATED"] = "1"
DotPopper::Automation.guard!

module DotPopperTest
  R = DotPopper::Rules::RADIUS

  def field(width = 800, height = 600) = DotPopper::Field.new(width, height, R)

  def dot(x, y, velocity_x: 0, velocity_y: 0, popped: false, bonus: false, id: (@ids = (@ids || 100) + 1))
    DotPopper::Dot.new(id:, x:, y:, velocity_x:, velocity_y:, radius: R, popped:, bonus:)
  end

  # A game whose dots are exactly the ones given, top first, in place of
  # the one it would spawn.
  def game_with(*dots, random: Random.new(1))
    DotPopper::Game.new(field, random:, dots: DotPopper::Stack.new(dots:))
  end

  # Each cabinet's one Starter (Cabinet#starter), taken by the first start
  # a test makes on it, as UseCases::StartGame takes it in the game.
  STARTERS = ObjectSpace::WeakKeyMap.new

  # Starts a game on +cabinet+, in play at once, or paused with +dots+
  # first for the tutorial; answers the cabinet.
  def start!(cabinet, seed = nil) = starter_of(cabinet).game(seed)
  def start_paused!(cabinet, dots, seed = nil) = starter_of(cabinet).paused(dots, seed)
  def starter_of(cabinet) = DotPopperTest.starter_of(cabinet)
  def self.starter_of(cabinet) = (STARTERS[cabinet] ||= cabinet.starter)

  # The game +cabinet+ holds itself, which nothing in the game can reach
  # (Cabinet#game is its read-only Game::View): for a test that sets up a
  # position by hand.
  def live(cabinet) = cabinet.instance_variable_get(:@game)

  # Sets a game's score as if earlier taps had earned it.
  def score!(game, points) = game.instance_variable_set(:@score, points)

  # Moves every dot of the game but +keep+ far out of the way.
  def clear_around!(game, keep)
    moved = game.dots.map_dots { it.id == keep.id ? it : it.with(x: -1000.0) }
    game.instance_variable_set(:@dots, moved)
  end
end
