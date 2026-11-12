# frozen_string_literal: true

module DotPopper
  # The rectangle dots live in, and the radius they all share. It knows
  # where a dot may be, so a dot stays on screen.
  class Field < Data.define(:width, :height, :radius)
    def initialize(width:, height:, radius:) = super(width: width.to_f, height: height.to_f, radius: radius.to_f)

    # A uniformly random point whose distance from every edge is at least
    # one radius, so a dot centered there starts wholly on screen. On a
    # field narrower than a dot, the center line is the only choice.
    def random_center(random)
      [random_between(random, min_x, max_x), random_between(random, min_y, max_y)]
    end

    # A random velocity for one axis: one of Rules::SPEEDS, in radii per
    # second, going either way.
    def random_speed(random)
      Rules::SPEEDS.sample(random:) * radius * [-1, 1].sample(random:)
    end

    def min_x = [radius, width / 2.0].min
    def max_x = [width - radius, width / 2.0].max
    def min_y = [radius, height / 2.0].min
    def max_y = [height - radius, height / 2.0].max

    private

    def random_between(random, low, high)
      low == high ? low.to_f : random.rand(low.to_f..high.to_f)
    end
  end
end
