# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a dot is drawn (assets/shaders/dot.glsl, and Shell::DotPainter's
    # plain shapes without it), in radii. A player aims at a moving dot by
    # its edge, so what is seen of a dot at rest ends where its hit circle
    # does, at 1: a fresh dot's bright +rim+ is the last of it, and only a
    # faint +halo+, +halo_width+ deep, and a dot's shadow, +shadow_alpha+
    # dark, fall outside it.
    #
    # +extent+ is the drawn square's half side, room for the halo, the
    # shadow and a wrong tap's glow; the shadow is a disc +shadow_reach+
    # across, dropped +shadow_offset+, so it shows which dot is on top;
    # +legend+ is the size of the title's example dots.
    class DotStyle < Data.define(:extent, :rim, :shadow_offset, :shadow_reach, :shadow_alpha, :halo_width,
                                :halo_alpha, :legend)
      # How strongly a fresh dot's halo shows +distance+ from its centre,
      # as the shader draws it.
      def halo(distance) = halo_alpha * Math.exp(-((([distance - 1, 0].max) / halo_width)**2))

      # The farthest below its centre a dot's shadow reaches.
      def shadow_edge = shadow_offset + shadow_reach
    end
  end
end
