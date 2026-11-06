# frozen_string_literal: true

module DotPopper
  module Shell
    # The setdef splash: its black ground over the whole window, and its
    # logotype (Presentation::Logotype) centred on it, in Workshop Yellow.
    # The letters sit on a faint glow, made of a few dim copies of them
    # moved a little way around, which needs no shader. Letters and block
    # are placed on whole device pixels. Presentation::Splash says how much
    # of each shows.
    class SplashPainter < Data.define(:pen)
      G = ::Lota::Graphics
      DIRECTIONS = 12
      RINGS = [0.5, 1.0].freeze # of the glow's reach
      GLOW_ALPHA = 0.012

      def draw(splash)
        width, height = G.dimensions
        pen.color(pen.look::SPLASH_INK, splash.ground)
        G.rectangle(:fill, 0, 0, width + 1, height + 1)
        return unless splash.mark.positive?

        logotype = Presentation::Logotype.fit(width, height)
        font = pen.fonts.wordmark(logotype.size)
        pixels = pen.pixels
        left = pixels.snap(logotype.left(width / 2.0))
        baseline = pixels.snap(logotype.baseline(height / 2.0))
        glow(logotype, font, left, baseline, splash.mark)
        letters(logotype, font, left, baseline, pen.look::SPLASH_YELLOW, splash.mark)
        block(logotype, left, baseline, splash.mark)
      end

      private

      def glow(logotype, font, left, baseline, alpha)
        reach = Presentation::Logotype::GLOW * logotype.size
        RINGS.each do |ring|
          DIRECTIONS.times do |i|
            angle = i * Math::PI * 2 / DIRECTIONS
            letters(logotype, font, left + (Math.cos(angle) * reach * ring), baseline + (Math.sin(angle) * reach * ring),
                    pen.look::SPLASH_YELLOW, GLOW_ALPHA * alpha)
          end
        end
      end

      def letters(logotype, font, left, baseline, color, alpha)
        pixels = pen.pixels
        pen.color(color, alpha)
        logotype.letters(left).each do |char, x|
          G.print(char, font, pixels.snap(x), pixels.snap(baseline - font.baseline))
        end
      end

      def block(logotype, left, baseline, alpha)
        pixels = pen.pixels
        x, width = logotype.block(left)
        pen.color(pen.look::SPLASH_YELLOW, alpha)
        G.rectangle(:fill, pixels.snap(x), pixels.snap(logotype.block_top(baseline)), pixels.whole(width),
                    pixels.whole(logotype.block_height))
      end
    end
  end
end
