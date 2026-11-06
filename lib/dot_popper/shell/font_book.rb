# frozen_string_literal: true

module DotPopper
  module Shell
    # The game's fonts, made once for each face and size and kept. Each is
    # made at its size in graphics units and rasterized at the screen's
    # pixel density, so text is drawn 1:1 with device pixels and never
    # scaled; a window moved to a screen of another density gets new ones.
    class FontBook
      def initialize(type)
        @type = type
        @fonts = {}
        @density = ::Lota::Graphics.dpi_scale
      end

      def bold(size) = font(@type.bold, size)
      def semibold(size) = font(@type.semibold, size)
      def wordmark(size) = font(@type.wordmark, size)

      def density=(density)
        return if density == @density

        @density = density
        forget
      end

      # Lets go of every font, since a new window size asks for new sizes.
      def forget = @fonts.clear

      private

      def font(path, size)
        size = [size.round, 1].max
        @fonts[[path, size]] ||= load(path, size)
      end

      def load(path, size)
        ::Lota::Graphics::Font.new(path, size, dpiscale: @density)
      rescue StandardError => e
        warn "Dot Popper: using Lota's own font (#{e.message})"
        ::Lota::Graphics::Font.new(size, dpiscale: @density)
      end
    end
  end
end
