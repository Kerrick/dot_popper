# frozen_string_literal: true

module DotPopper
  module Presentation
    # A glow that lights the screen's edges, never its middle: +color+, its
    # strongest +alpha+, how many seconds it takes to fade, and how far in
    # it reaches, as a part of the screen's shorter side.
    class FlashStyle < Data.define(:color, :alpha, :duration, :band); end

    # An edge glow lit at +born+: bright at once, then fading out.
    class EdgeFlash < Data.define(:style, :born)
      NONE = new(style: nil, born: -Float::INFINITY)

      def color = style&.color
      def band = style&.band.to_f

      def alpha(now)
        elapsed = now - born
        return 0.0 if style.nil? || elapsed >= style.duration

        style.alpha * (1 - Ease.out_cubic(elapsed / style.duration))
      end
    end
  end
end
