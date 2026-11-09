# frozen_string_literal: true

module DotPopper
  module Presentation
    # How an expanding ring looks: its radius and line width over time,
    # both in radii, its opacity over time, and its color.
    class RingStyle < Data.define(:radius, :width, :alpha, :color)
      def duration = [radius.duration, width.duration, alpha.duration].max
    end

    # One ring spreading out since +born+: a pop's shockwave, the ripple
    # that marks a new dot sliding in underneath, or a wrong tap's flash on
    # a dot's rim. A ring around a dot +follow+s that dot's id, so it moves
    # with the dot; one without stays at (+x+, +y+). +scale+ is the radius
    # in graphics units.
    class Ring < Data.define(:x, :y, :style, :scale, :born, :follow)
      def initialize(x:, y:, style:, scale:, born:, follow: nil) = super

      # Where the ring's centre is, given the dots in play.
      def center(dots)
        dot = follow && dots&.find { it.id == follow }
        dot ? [dot.x, dot.y] : [x, y]
      end
      def alive?(now) = now - born < style.duration

      def radius(now) = style.radius.at(now - born) * scale
      def width(now) = [style.width.at(now - born) * scale, 0.0].max
      def alpha(now) = style.alpha.at(now - born).clamp(0.0, 1.0)
    end
  end
end
