# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the Tutorial's spotlight looks: how dark it makes everything
    # around its light (0 to 1), how long it takes to move or fade, the
    # light's soft edge, and how far around a dot it reaches, both in
    # radii.
    class SpotlightStyle < Data.define(:dim, :move, :feather, :dot); end

    # The Tutorial's spotlight: everything dims but a circle of light
    # around +to+ (an Anchor), which it moved to from +from+ since +at+.
    # Either may be nil: from nothing, the dim fades in around +to+; to
    # nothing, it fades out around where it was.
    class Spotlight < Data.define(:from, :to, :at, :style)
      def self.off(style) = new(from: nil, to: nil, at: -Float::INFINITY, style:)

      # The spotlight moving to +anchor+, or fading out for nil.
      def toward(anchor, now) = anchor == to ? self : with(from: to, to: anchor, at: now)

      # How far it has moved from +from+ to +to+, 0 to 1.
      def progress(now) = Ease.in_out_sine((now - at) / style.move)

      # How much of the dim shows, 0 to 1.
      def strength(now)
        if from.nil? && to.nil? then 0.0
        elsif from.nil? then progress(now)
        elsif to.nil? then 1 - progress(now)
        else 1.0
        end
      end

      # How dark the dim is now.
      def darkness(now) = style.dim * strength(now)
    end
  end
end
