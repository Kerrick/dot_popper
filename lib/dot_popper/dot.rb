# frozen_string_literal: true

module DotPopper
  # One dot at one moment: where it is, how fast it goes on each axis, and
  # whether it has been popped. A dot is a value; moving or popping it
  # gives a new dot with the same +id+, so anything that follows a dot
  # through a game, such as its animation, follows the id.
  class Dot < Data.define(:id, :x, :y, :velocity_x, :velocity_y, :radius, :popped, :bonus)
    def self.spawn(field, random, id:)
      x, y = field.random_center(random)
      new(id:, x:, y:, velocity_x: field.random_speed(random), velocity_y: field.random_speed(random),
          radius: field.radius)
    end

    def initialize(id:, x:, y:, velocity_x:, velocity_y:, radius:, popped: false, bonus: false)
      super(id:, x: x.to_f, y: y.to_f, velocity_x: velocity_x.to_f, velocity_y: velocity_y.to_f, radius: radius.to_f,
            popped:, bonus:)
    end

    def popped? = popped
    def bright? = !popped

    # Whether this is a bonus dot, earned by a row (Rules::BONUS). It is
    # the bright dot to pop, only styled apart; popped, it is a popped dot.
    def bonus? = bonus

    # The same dot, popped. Popping changes only how a tap treats it and
    # how it looks; a popped dot keeps moving for the rest of the game.
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

    # The same dot moved from field +from+ to field +to+, as a window is
    # resized or a phone turned: as far across and down the new field's
    # room as it was across the old one's, so a dot 70% of the way across
    # stays 70% of the way across, then confined to it. Its velocity, in
    # radii per second, is unchanged.
    def refit(from, to)
      with(x: share(x, from.min_x, from.max_x, to.min_x, to.max_x),
           y: share(y, from.min_y, from.max_y, to.min_y, to.max_y)).confine(to)
    end

    private

    # +position+ moved from the span +low+..+high+ to +new_low+..+new_high+
    # in proportion; from a span of none, to the new one's middle.
    def share(position, low, high, new_low, new_high)
      fraction = high > low ? (position - low) / (high - low) : 0.5
      new_low + (fraction * (new_high - new_low))
    end

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
