# frozen_string_literal: true

module DotPopper
  module Presentation
    # A glow that lights the screen's edges, never its middle: +color+, its
    # strongest +alpha+, how many seconds it takes to fade, and how far in
    # it reaches, as a part of the screen's shorter side.
    class FlashLook < Data.define(:color, :alpha, :duration, :band); end

    # An edge glow lit at +born+: bright at once, then fading out.
    class EdgeFlash < Data.define(:look, :born)
      NONE = new(look: nil, born: -Float::INFINITY)

      def color = look&.color
      def band = look&.band.to_f

      def alpha(now)
        elapsed = now - born
        return 0.0 if look.nil? || elapsed >= look.duration

        look.alpha * (1 - Ease.out_cubic(elapsed / look.duration))
      end
    end
  end
end
