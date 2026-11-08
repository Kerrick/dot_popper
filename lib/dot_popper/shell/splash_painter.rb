# frozen_string_literal: true

module DotPopper
  module Shell
    # The setdef splash: its black ground over the whole window, and its
    # logotype (Presentation::Logotype) centred on it, in Workshop Yellow.
    # The letters sit on a faint, smooth glow, the letters blurred by the
    # Bloom and added to the ground; where there is no blur shader there
    # is no glow. The block blinks, as Presentation::Splash says. Letters
    # and block are placed on whole device pixels.
    # Presentation::Splash says how much of each shows.
    class SplashPainter
      G = ::Lota::Graphics
      GLOW = Presentation::BloomLook.new(strength: 0.22, sigma: 3.0, passes: 3, resolution: 0.3)

      def initialize(pen:)
        @pen = pen
        @glow = Bloom.new(pen, GLOW)
      end

      # Makes the glow's canvases again, after a resize.
      def refresh = @glow.refresh

      def draw(splash)
        width, height = G.dimensions
        @pen.color(@pen.look::SPLASH_INK, splash.ground)
        G.rectangle(:fill, 0, 0, width + 1, height + 1)
        return unless splash.mark.positive?

        logotype = Presentation::Logotype.fit(width, height)
        font = @pen.fonts.wordmark(logotype.size)
        pixels = @pen.pixels
        left = pixels.snap(logotype.left(width / 2.0))
        baseline = pixels.snap(logotype.baseline(height / 2.0))
        @glow.glow(splash.mark) { letters(logotype, font, left, baseline, 1.0) }
        letters(logotype, font, left, baseline, splash.mark)
        block(logotype, left, baseline, splash.mark * splash.block)
      end

      private

      def letters(logotype, font, left, baseline, alpha)
        pixels = @pen.pixels
        @pen.color(@pen.look::SPLASH_YELLOW, alpha)
        logotype.letters(left).each do |char, x|
          G.print(char, font, pixels.snap(x), pixels.snap(baseline - font.baseline))
        end
      end

      def block(logotype, left, baseline, alpha)
        pixels = @pen.pixels
        x, width = logotype.block(left)
        @pen.color(@pen.look::SPLASH_YELLOW, alpha)
        G.rectangle(:fill, pixels.snap(x), pixels.snap(logotype.block_top(baseline)), pixels.whole(width),
                    pixels.whole(logotype.block_height))
      end
    end
  end
end
