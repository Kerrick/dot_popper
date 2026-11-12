# frozen_string_literal: true

module DotPopper
  # Where on a fresh dot a fingertip could land: the centers a touch
  # target, a circle Rules::TOUCH_TARGET units across, may have while lying
  # wholly on a dot of a given radius. The target is the same size
  # whatever the dot's radius, because a fingertip is.
  #
  # The centers are samples of the disc +reach+ around the dot's center:
  # rings SPACING apart, each with points about SPACING apart along it and
  # every other ring turned by half a point, then the center itself. The
  # outermost ring comes first, because a dot partly covered is open at
  # its edge.
  #
  # Every point of the disc is then within 3.5 units of a sample, for any
  # radius from 30 to 120 (the tests check it), so a target this misses
  # has less than 3.5 units to spare around its 22-unit radius: an opening
  # a fingertip could barely use. Samples are only ever real centers, so a
  # target it finds is always a real one.
  class TouchTarget < Data.define(:reach, :offsets)
    HALF = Rules::TOUCH_TARGET / 2.0
    SPACING = 5.0

    # The target on a dot of +radius+. A dot under TOUCH_TARGET across,
    # smaller than the rules allow, has no room for one: its reach is
    # negative and it has no centers.
    def self.on(radius)
      reach = radius.to_f - HALF
      new(reach:, offsets: reach.negative? ? [] : rings(reach))
    end

    def self.rings(reach)
      count = (reach / SPACING).ceil
      rings = count.downto(1).flat_map { |ring| ring(reach * ring / count, ring.even? ? 0.5 : 0.0) }
      [*rings, [0.0, 0.0]]
    end

    def self.ring(radius, turn)
      points = (2 * Math::PI * radius / SPACING).ceil
      Array.new(points) do |point|
        angle = 2 * Math::PI * (point + turn) / points
        [radius * Math.cos(angle), radius * Math.sin(angle)]
      end
    end

    def initialize(reach:, offsets:) = super(reach: reach.to_f, offsets: offsets.freeze)

    def fits? = !reach.negative?

    # Whether +dot+, above a dot centered at (+x+, +y+), leaves no room for
    # a target anywhere on it.
    def covered_by?(x, y, dot) = Math.hypot(dot.x - x, dot.y - y) + reach < dot.radius + HALF

    # Whether a target fits on a dot centered at (+x+, +y+) and clear of
    # every dot in +above+, touching allowed.
    def clear_on?(x, y, above)
      near = above.filter_map do |dot|
        offset_x = dot.x - x
        offset_y = dot.y - y
        apart = Math.hypot(offset_x, offset_y)
        clearance = dot.radius + HALF
        next unless apart < reach + clearance
        return false if apart + reach < clearance # covered_by?(x, y, dot)

        [offset_x, offset_y, clearance**2, apart] #: [Float, Float, Float, Float]
      end
      return true if near.empty?

      near.sort_by!(&:last) # the closest dot rules out the most centers, so it is asked first
      offsets.any? do |dx, dy|
        near.none? { |offset_x, offset_y, limit| ((offset_x - dx)**2) + ((offset_y - dy)**2) < limit }
      end
    end
  end
end
