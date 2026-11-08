# frozen_string_literal: true

module DotPopper
  module Shell
    # The pointing hand's PNGs (Presentation::PointingHand), each loaded
    # the first time it is wanted and kept. Each has its mipmaps and
    # linear filtering, so drawn a little smaller than its pixels, it is
    # smooth and crisp, as an icon is.
    class HandSprites
      G = ::Lota::Graphics

      def initialize = @sprites = {}

      # The PNG to draw for a hand +pixels+ across.
      def for(pixels)
        size = Presentation::PointingHand.size_for(pixels)
        @sprites[size] ||= load(size)
      end

      private

      def load(size)
        sprite = G::Image.new("assets/emoji/hand-#{size}.png", mipmaps: true, dpiscale: 1)
        sprite.filter = :linear, :linear
        sprite.mipmap_filter = :linear
        sprite
      end
    end
  end
end
