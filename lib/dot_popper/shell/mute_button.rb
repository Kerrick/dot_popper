# frozen_string_literal: true

module DotPopper
  module Shell
    # The speaker in the title's corner: sound waves when sound is on, a
    # cross when it is off. A tap on it toggles sound (Show#tap).
    class MuteButton
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      def draw(rect, muted)
        pixels = @pen.pixels
        size = rect.width
        x = pixels.snap(rect.center_x)
        y = pixels.snap(rect.center_y)
        @pen.color(@pen.palette.pill)
        G.circle(:fill, x, y, size / 2.0, 48)
        @pen.color(@pen.palette.soft)
        speaker(x, y, size)
        muted ? cross(x, y, size) : waves(x, y, size)
      end

      private

      def speaker(x, y, size)
        u = size / 100.0
        G.rectangle(:fill, @pen.pixels.snap(x - (24 * u)), @pen.pixels.snap(y - (9 * u)), @pen.pixels.snap(11 * u),
                    @pen.pixels.snap(18 * u))
        G.polygon(:fill, x - (14 * u), y - (9 * u), x + (2 * u), y - (22 * u), x + (2 * u), y + (22 * u),
                  x - (14 * u), y + (9 * u))
      end

      def waves(x, y, size)
        u = size / 100.0
        G.line_width = @pen.pixels.whole(4.5 * u)
        [12, 22].each { G.arc(:line, :open, x + (4 * u), y, it * u, -0.85, 0.85, 16) }
      end

      def cross(x, y, size)
        u = size / 100.0
        G.line_width = @pen.pixels.whole(4.5 * u)
        left = x + (11 * u)
        right = x + (27 * u)
        G.line(left, y - (8 * u), right, y + (8 * u))
        G.line(left, y + (8 * u), right, y - (8 * u))
      end
    end
  end
end
