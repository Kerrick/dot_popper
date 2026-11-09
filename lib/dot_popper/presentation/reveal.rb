# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the hidden fresh dot is shown after a wrong tap: a dashed
    # outline, the drawing convention for an edge out of sight, that
    # settles onto the dot's rim (+radius+, in radii) and fades (+alpha+).
    # +width+ is its line, in radii, and +dashes+ how many it has.
    class RevealStyle < Data.define(:radius, :alpha, :width, :dashes, :color)
      def duration = [radius.duration, alpha.duration].max
    end

    # "It was under there": the outline of the fresh dot that a wrong tap
    # was too soon for, drawn over every dot since +born+. It follows its
    # dot's id, so it moves with the dot. +scale+ is the radius in
    # graphics units.
    class Reveal < Data.define(:follow, :x, :y, :style, :scale, :born)
      def center(dots)
        dot = dots&.find { it.id == follow }
        dot ? [dot.x, dot.y] : [x, y]
      end

      def alive?(now) = now - born < style.duration

      def radius(now) = style.radius.at(now - born) * scale
      def width = style.width * scale
      def alpha(now) = style.alpha.at(now - born).clamp(0.0, 1.0)

      # The dashes as [from, to] angles, in radians, turning slowly so the
      # outline reads as drawn, not stamped.
      def dashes(now)
        step = 2 * Math::PI / style.dashes
        turn = (now - born) * 0.6
        Array.new(style.dashes) { [(it * step) + turn, (it * step) + turn + (step * 0.58)] }
      end
    end
  end
end
