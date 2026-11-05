# frozen_string_literal: true

module DotPopper
  module Presentation
    # A soft, dark backing behind a block of text, so it reads over what
    # moves behind it: at most +alpha+ in its middle, fading to nothing
    # over +feather+ graphics units at its edges (at a layout scale of
    # 1), in +layers+ steps, and +pad+ units wider than the text on every
    # side.
    class ScrimLook < Data.define(:alpha, :feather, :layers, :pad)
      # Each layer's opacity: drawn one inside the other, so the middle is
      # covered by every layer, they add up to +alpha+ there.
      def layer_alpha = 1 - ((1 - alpha)**(1.0 / layers))

      # How far in from the scrim's outer edge each layer starts, outermost
      # first, given the feather in graphics units.
      def insets(feather) = (0...layers).map { feather * it / layers.to_f }
    end
  end
end
