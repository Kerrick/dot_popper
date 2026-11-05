# frozen_string_literal: true

module DotPopper
  # One dot: where it is, how fast it goes on each axis, and whether it has
  # been popped. Popping changes only how a tap treats it; a popped dot
  # keeps moving for the rest of the round.
  class Dot
    attr_reader :x, :y, :velocity_x, :velocity_y, :radius

    def self.spawn(field, random)
      x, y = field.random_center(random)
      new(x:, y:, velocity_x: field.random_speed(random), velocity_y: field.random_speed(random), radius: field.radius)
    end

    def initialize(x:, y:, velocity_x:, velocity_y:, radius:)
      @x = x.to_f
      @y = y.to_f
      @velocity_x = velocity_x.to_f
      @velocity_y = velocity_y.to_f
      @radius = radius
      @popped = false
    end

    def popped? = @popped
    def fresh? = !@popped

    def pop
      @popped = true
      self
    end

    # Whether a point lies on this dot, edge included. The hit circle is
    # always the dot's radius, whatever the dot looks like.
    def covers?(point_x, point_y)
      ((point_x - x)**2) + ((point_y - y)**2) <= radius**2
    end

    # Moves the dot by its velocity over +seconds+, reflecting off the
    # field's edges. A dot that would pass an edge comes back by as far as
    # it went past, so the distance it travels does not depend on the
    # frame rate.
    def move(seconds, field)
      @x, @velocity_x = bounce(x + (velocity_x * seconds), velocity_x, field.min_x, field.max_x)
      @y, @velocity_y = bounce(y + (velocity_y * seconds), velocity_y, field.min_y, field.max_y)
      self
    end

    # Puts the dot back inside a field that has changed size.
    def confine(field)
      @x = x.clamp(field.min_x, field.max_x)
      @y = y.clamp(field.min_y, field.max_y)
      self
    end

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
