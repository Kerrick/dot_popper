# frozen_string_literal: true

module DotPopper
  module Presentation
    # The left +amount+ (0 to 1) of a pill-shaped button +rect+, as the
    # outline of a filled polygon, so a fill growing across the pill keeps
    # to its rounded ends from its first frame. A rounded rectangle as
    # narrow as the fill would stand the pill's full height above and
    # below its curve; this follows the curve instead. +steps+ points
    # trace each rounded end.
    class PillFill < Data.define(:rect, :amount)
      STEPS = 24

      # The outline as x, y pairs in one flat array, top edge left to
      # right and then bottom edge back, or empty when there is nothing
      # to fill. The shape is convex, as Lota::Graphics.polygon needs.
      def outline(steps = STEPS)
        reach = rect.x + (rect.width * amount.clamp(0.0, 1.0))
        return [] if reach <= rect.x

        xs = columns(reach, steps)
        top = xs.flat_map { [it, rect.center_y - half_height_at(it)] }
        bottom = xs.reverse.flat_map { [it, rect.center_y + half_height_at(it)] }
        top + bottom
      end

      private

      def radius = rect.height / 2.0

      # Where to measure the pill's height: along each rounded end, as far
      # as the fill reaches, and at the fill's edge.
      def columns(reach, steps)
        left = rect.x + radius
        right = rect.right - radius
        ends = (0..steps).map { rect.x + (radius * it / steps.to_f) } +
               (0..steps).map { right + (radius * it / steps.to_f) }
        (ends.select { it < reach } + [left, right].select { it < reach } + [reach]).uniq.sort
      end

      # Half the pill's height at +x+: the full radius along its straight
      # middle, less along its rounded ends.
      def half_height_at(x)
        left = rect.x + radius
        right = rect.right - radius
        off = if x < left then left - x
              elsif x > right then x - right
              else 0.0
              end
        Math.sqrt([(radius * radius) - (off * off), 0.0].max)
      end
    end
  end
end
