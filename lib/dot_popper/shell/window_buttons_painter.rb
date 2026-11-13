# frozen_string_literal: true

module DotPopper
  module Shell
    # Home's window buttons on a desktop, quiet pills as "How to
    # play" is, each with its icon drawn in shapes: "Full screen", four
    # corners pointing out, which in fullscreen point in and say
    # "Window"; and Quit, the power sign (IEC 5009), a ring broken at the
    # top with a stroke down into it. Where the plan has no room for
    # their words, they are their icons alone, game. Every stroke is
    # whole device pixels wide, and the corners' sit on whole pixels.
    class WindowButtonsPainter < Data.define(:pen)
      G = ::Lota::Graphics
      STROKE = 0.045 # an icon's stroke, in the button's height, at least a device pixel
      CORNERS = 0.2 # how far out the corners reach from the middle, in the button's height
      ARM = 0.6 # each corner's arms, in that reach
      POWER = 0.17 # the power sign's ring's radius, in the button's height
      GAP = 0.75 # half the ring's break at the top, in radians

      def draw(buttons, show, alpha)
        hover = show.hover
        fullscreen = show.window.fullscreen?
        words = show.words
        labeled = buttons.labeled
        PillButton.new(pen:).draw(buttons.fullscreen, (words.fullscreen_button(fullscreen) if labeled), alpha:,
                                  hover: hover.level(:fullscreen),
                                  icon: ->(x, y, size) { corners(x, y, size, !fullscreen, alpha) })
        PillButton.new(pen:).draw(buttons.quit, (words.quit if labeled), alpha:, hover: hover.level(:quit),
                                  icon: ->(x, y, size) { power(x, y, size, alpha) })
      end

      private

      # Four corners around +x+, +y+, their arms pointing in from the
      # square's corners (+out+, to fill the screen) or out from near its
      # middle (back to a window), each arm a rectangle on whole pixels.
      def corners(x, y, size, out, alpha)
        pixels = pen.pixels
        x = pixels.snap(x)
        y = pixels.snap(y)
        stroke = stroke(size)
        reach = pixels.whole(size * CORNERS)
        arm = pixels.whole(reach * ARM)
        corner = out ? reach : reach - arm
        pen.color(pen.palette.cream, alpha)
        run = out ? -1 : 1 # the arms run from each corner back toward the middle, or out from it
        [-1, 1].product([-1, 1]) do |across, down|
          vx = x + (across * corner)
          vy = y + (down * corner)
          bar(vx, vy, vx + (across * run * arm), vy + (down * run * stroke))
          bar(vx, vy, vx + (across * run * stroke), vy + (down * run * arm))
        end
      end

      # The power sign around +x+, +y+: the ring, open at the top, and the
      # stroke from above it down to near the middle.
      def power(x, y, size, alpha)
        pixels = pen.pixels
        stroke = stroke(size)
        count = (stroke * pixels.scale).round
        radius = pixels.snap(size * POWER)
        cx = pixels.line_at(x, count)
        cy = pixels.snap(y) + pixels.snap(size * 0.02)
        pen.color(pen.palette.cream, alpha)
        G.line_width = stroke
        top = -Math::PI / 2
        G.arc(:line, :open, cx, cy, radius, top + GAP, top + (2 * Math::PI) - GAP, 40)
        left = pixels.snap(x) - ((count / 2) / pixels.scale)
        bar(left, pixels.snap(cy - (radius * 1.2)), left + stroke, pixels.snap(cy - (radius * 0.1)))
      end

      def stroke(size) = pen.pixels.whole(size * STROKE)

      # A filled rectangle between corners +x1+, +y1+ and +x2+, +y2+.
      def bar(x1, y1, x2, y2)
        left, right = [x1, x2].minmax
        top, bottom = [y1, y2].minmax
        G.rectangle(:fill, left, top, right - left, bottom - top)
      end
    end
  end
end
