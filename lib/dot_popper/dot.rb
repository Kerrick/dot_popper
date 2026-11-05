# frozen_string_literal: true

module DotPopper
  # One dot at one moment: where it is, how fast it goes on each axis, and
  # whether it has been popped. A dot is a value; moving or popping it
  # gives a new dot with the same +id+, so anything that follows a dot
  # through a round, such as its animation, follows the id.
  class Dot < Data.define(:id, :x, :y, :velocity_x, :velocity_y, :radius, :popped)
    def self.spawn(field, random, id:)
      x, y = field.random_center(random)
      new(id:, x:, y:, velocity_x: field.random_speed(random), velocity_y: field.random_speed(random),
          radius: field.radius)
    end

    def initialize(id:, x:, y:, velocity_x:, velocity_y:, radius:, popped: false)
      super(id:, x: x.to_f, y: y.to_f, velocity_x: velocity_x.to_f, velocity_y: velocity_y.to_f, radius:, popped:)
    end

    def popped? = popped
    def fresh? = !popped

    # The same dot, popped. Popping changes only how a tap treats it and
    # how it looks; a popped dot keeps moving for the rest of the round.
    def pop = with(popped: true)

    # Whether a point lies on this dot, edge included. The hit circle is
    # always the dot's radius, whatever the dot looks like.
    def covers?(point_x, point_y)
      ((point_x - x)**2) + ((point_y - y)**2) <= radius**2
    end

    # Whether this dot's disc and +other+'s share any point.
    def overlaps?(other) = Math.hypot(x - other.x, y - other.y) <= radius + other.radius

    # Where the dot is +seconds+ later, reflecting off the field's edges.
    # A dot that would pass an edge comes back by as far as it went past,
    # so the distance it travels does not depend on the frame rate.
    def move(seconds, field)
      new_x, new_velocity_x = bounce(x + (velocity_x * seconds), velocity_x, field.min_x, field.max_x)
      new_y, new_velocity_y = bounce(y + (velocity_y * seconds), velocity_y, field.min_y, field.max_y)
      with(x: new_x, y: new_y, velocity_x: new_velocity_x, velocity_y: new_velocity_y)
    end

    # The same dot, back inside a field that has changed size.
    def confine(field) = with(x: x.clamp(field.min_x, field.max_x), y: y.clamp(field.min_y, field.max_y))

    private

    # Unfolding the path onto a line twice the span long gives the exact
    # position however many edges a long frame crosses: the first half of
    # that line is the field going one way, the second half coming back.
    def bounce(position, velocity, low, high)
      return [low, velocity] if low >= high

      span = high - low
      offset = (position - low) % (2 * span)
      offset <= span ? [low + offset, velocity] : [high - (offset - span), -velocity]
    end
  end
end
