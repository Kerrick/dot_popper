# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a floating number moves: how far it rises (radii), and how long
    # it lives (seconds).
    class FloaterLook < Data.define(:rise, :life)
      def rise_tween = Tween.new(from: 0.0, to: rise, duration: life, ease: :out_cubic)
    end

    # A short piece of text, such as "+1" or "−2s", that rises from where
    # it happened and fades fast.
    class Floater
      attr_reader :text, :color

      def initialize(text:, x:, y:, color:, look:, scale:)
        @text = text
        @x = x
        @y = y
        @color = color
        @look = look
        @scale = scale
        @age = 0.0
      end

      def update(seconds) = @age += seconds
      def alive? = @age < @look.life

      def x = @x
      def y = @y - (@look.rise_tween.at(@age) * @scale)
      def progress = (@age / @look.life).clamp(0.0, 1.0)

      # Fully there for its first third, then gone quickly.
      def alpha = 1 - Ease.in_quad(((progress - 0.35) / 0.65).clamp(0.0, 1.0))
    end
  end
end
