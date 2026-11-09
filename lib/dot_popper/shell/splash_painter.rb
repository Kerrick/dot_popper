# frozen_string_literal: true

module DotPopper
  module Shell
    # The setdef splash: its black ground over the whole window, and its
    # logotype (Presentation::Logotype) centred on it, in setdef's amber.
    # The letters and the block sit on setdef's glow (brand/README.md):
    # both blurred by a Bloom, in the mark's own colour at 55%, under the
    # crisp mark. The blur is a fixed share of the logotype's size
    # (Logotype#glow), so it looks alike at every window size; where there
    # is no blur shader there is no glow. The block blinks, as Presentation::Splash says, and
    # its glow follows its own lit level: "The block cursor glows exactly
    # when the letters glow, and is flat when they're flat." Letters and
    # block are placed on whole device pixels.
    # Presentation::Splash says how much of each shows.
    class SplashPainter
      G = ::Lota::Graphics

      def initialize(pen:)
        @pen = pen
        refresh
      end

      # Makes the glow again for the window's size now, after a resize.
      def refresh
        width, height = G.dimensions
        @glow = Bloom.new(@pen, Presentation::Logotype.fit(width, height).glow(G.dpi_scale))
      end

      def draw(splash)
        width, height = G.dimensions
        @pen.color(@pen.style::SPLASH_INK, splash.ground)
        G.rectangle(:fill, 0, 0, width + 1, height + 1)
        return unless splash.mark.positive?

        logotype = Presentation::Logotype.fit(width, height)
        font = @pen.fonts.wordmark(logotype.size)
        pixels = @pen.pixels
        left = pixels.snap(logotype.left(width / 2.0))
        baseline = pixels.snap(logotype.baseline(height / 2.0))
        @glow.glow(splash.mark) do
          letters(logotype, font, left, baseline, 1.0)
          block(logotype, left, baseline, splash.block)
        end
        letters(logotype, font, left, baseline, splash.mark)
        block(logotype, left, baseline, splash.mark * splash.block)
      end

      private

      def letters(logotype, font, left, baseline, alpha)
        pixels = @pen.pixels
        @pen.color(@pen.style::SPLASH_YELLOW, alpha)
        logotype.letters(left).each do |char, x|
          G.print(char, font, pixels.snap(x), pixels.snap(baseline - font.baseline))
        end
      end

      def block(logotype, left, baseline, alpha)
        pixels = @pen.pixels
        x, width = logotype.block(left)
        @pen.color(@pen.style::SPLASH_YELLOW, alpha)
        G.rectangle(:fill, pixels.snap(x), pixels.snap(logotype.block_top(baseline)), pixels.whole(width),
                    pixels.whole(logotype.block_height))
      end
    end
  end
end
