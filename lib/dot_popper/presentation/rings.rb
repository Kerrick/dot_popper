# frozen_string_literal: true

module DotPopper
  module Presentation
    # How an expanding ring looks: its radius and line width over time,
    # both in radii, its opacity over time, and its color.
    class RingLook < Data.define(:radius, :width, :alpha, :color)
      def duration = [radius.duration, width.duration, alpha.duration].max
    end

    # One ring spreading out from a point: a pop's shockwave, or the ripple
    # that marks a new dot sliding in underneath.
    class Ring
      attr_reader :x, :y, :look

      def initialize(x, y, look, scale)
        @x = x
        @y = y
        @look = look
        @scale = scale
        @age = 0.0
      end

      def update(seconds) = @age += seconds
      def alive? = @age < look.duration

      def radius = look.radius.at(@age) * @scale
      def width = [look.width.at(@age) * @scale, 0.0].max
      def alpha = look.alpha.at(@age).clamp(0.0, 1.0)
    end
  end
end
