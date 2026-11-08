# frozen_string_literal: true

module DotPopper
  # How much of a dot a player could see, and so tap: the share of its
  # disc that no dot above it covers. A tap reaches only the topmost dot
  # (Stack#top_at), so what lies under another dot may as well not be
  # there.
  #
  # The share is counted over SAMPLES points spread evenly across the
  # disc (a sunflower spiral, the same for every dot), so it is within
  # about half a percent of the true area, and a dot is reported as fully
  # visible only if no sample is covered. It is the same measure whatever
  # the dot's radius.
  module Visibility
    SAMPLES = 400
    GOLDEN_ANGLE = Math::PI * (3 - Math.sqrt(5))

    # Unit-disc offsets, as [x, y] pairs of fractions of the radius.
    POINTS = Array.new(SAMPLES) do |index|
      reach = Math.sqrt((index + 0.5) / SAMPLES)
      angle = index * GOLDEN_ANGLE
      [reach * Math.cos(angle), reach * Math.sin(angle)].freeze
    end.freeze #: Array[[Float, Float]]

    # The share of +dot+, from 0.0 to 1.0, that none of the dots in
    # +above+ covers.
    def self.of(dot, above)
      near = above.select { it.overlaps?(dot) }
      return 1.0 if near.empty?

      open = POINTS.count do |across, down|
        x = dot.x + (across * dot.radius)
        y = dot.y + (down * dot.radius)
        near.none? { it.covers?(x, y) }
      end
      open.fdiv(SAMPLES)
    end
  end
end
