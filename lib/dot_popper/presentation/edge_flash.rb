# frozen_string_literal: true

module DotPopper
  module Presentation
    # A glow that lights the screen's edges, never its middle: +color+, its
    # strongest +alpha+, and how many seconds it takes to fade.
    class FlashLook < Data.define(:color, :alpha, :duration); end

    # An edge glow lit at +born+: bright at once, then fading out.
    class EdgeFlash < Data.define(:look, :born)
      NONE = new(look: nil, born: -Float::INFINITY)

      def color = look&.color

      def alpha(now)
        elapsed = now - born
        return 0.0 if look.nil? || elapsed >= look.duration

        look.alpha * (1 - Ease.out_cubic(elapsed / look.duration))
      end
    end
  end
end
