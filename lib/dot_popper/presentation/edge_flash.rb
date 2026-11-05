# frozen_string_literal: true

module DotPopper
  module Presentation
    # A glow that lights the screen's edges, never its middle: +color+, its
    # strongest +alpha+, and how many seconds it takes to fade.
    class FlashLook < Data.define(:color, :alpha, :duration); end

    # The edge glow at each moment: bright at once, then fading out.
    class EdgeFlash
      def initialize
        @look = nil
        @age = 0.0
      end

      def trigger(look)
        @look = look
        @age = 0.0
      end

      def update(seconds) = @age += seconds

      def color = @look&.color

      def alpha
        return 0.0 if @look.nil? || @age >= @look.duration

        @look.alpha * (1 - Ease.out_cubic(@age / @look.duration))
      end
    end
  end
end
