# frozen_string_literal: true

module DotPopper
  module Shell
    # The Tutorial's ghost hand, drawn as the player's own hand on the
    # input they last used (Presentation::InputKind): a fingertip for a
    # touchscreen, a mouse pointer that clicks, or a gamepad's reticle with
    # its A button beside it. It is pale and see-through, so the dot under
    # it shows, and each press rings where it lands. Its letter sits on
    # whole device pixels; the hand itself moves smoothly.
    class GhostPainter < Data.define(:pen)
      G = ::Lota::Graphics
      ALPHA = 0.85 # how much of the hand shows at most
      RING = 0.4 # seconds a press's ring lasts

      # A pointer's outline, its tip at 0, 0, in twentieths of its height.
      ARROW = [[0, 0], [0, 17], [4, 13], [7, 20], [10, 19], [7, 12], [12, 12]].freeze
      # ...filled as convex pieces: a fan from the tip, and the tail.
      PIECES = [[0, 1, 2], [0, 2, 5], [0, 5, 6], [2, 3, 4, 5]].freeze

      def draw(pose, input, radius)
        return unless pose && pose.alpha.positive?

        case input.name
        in :touch then fingertip(pose, radius)
        in :mouse then pointer(pose, radius)
        in :gamepad then gamepad(pose, radius)
        end
      end

      private

      def palette = pen.palette

      # A finger reaching in from below and to the right, its pad on the
      # point it taps; it presses in a little as it goes down.
      def fingertip(pose, radius)
        alpha = pose.alpha * ALPHA
        ring(pose.x, pose.y, pose, radius * 0.35, radius * 0.95)
        width = radius * 0.8
        length = radius * 2.7
        G.push do
          G.translate(pose.x, pose.y)
          G.rotate(-0.55)
          press = 1 - (0.08 * pose.press)
          G.scale(press, press)
          edge = pen.pixels.line_width(2)
          pen.color(palette.shadow, alpha * 0.6)
          capsule(-(width / 2.0) - edge, -(width / 2.0) - edge, width + (2 * edge), length)
          pen.color(palette.cream, alpha)
          capsule(-width / 2.0, -width / 2.0, width, length)
          pen.color(palette.fresh_light.mix(palette.urgent, 0.25), alpha)
          nail = width * 0.56
          G.rectangle(:fill, -nail / 2.0, -width * 0.36, nail, nail * 0.95, nail * 0.42, nail * 0.42, 16)
        end
      end

      def capsule(x, y, width, length)
        corner = width / 2.0
        G.rectangle(:fill, x, y, width, length, corner, corner, 24)
      end

      # The system's arrow, pale, its tip on the point; a click shrinks it
      # for a moment and sends out three short rays, and no ring, which
      # would look like a gamepad's reticle.
      def pointer(pose, radius)
        alpha = pose.alpha * ALPHA
        rays(pose, radius, alpha)
        unit = radius * 1.1 / 20.0 * (1 - (0.12 * pose.press))
        points = ARROW.map { |x, y| [pose.x + (x * unit), pose.y + (y * unit)] }
        pen.color(palette.cream, alpha)
        PIECES.each { |piece| G.polygon(:fill, *piece.flat_map { points[it] }) }
        pen.color(palette.shadow, alpha)
        G.line_width = pen.pixels.line_width(2)
        G.polygon(:line, *points.flatten)
      end

      def rays(pose, radius, alpha)
        since = pose.since_press or return
        fade = 1 - (since / RING)
        return unless fade.positive?

        pen.color(palette.cream, alpha * fade)
        G.line_width = pen.pixels.line_width(3)
        [Math::PI, Math::PI * 1.25, Math::PI * 1.5].each do |angle|
          from = radius * (0.25 + (0.15 * (1 - fade)))
          to = from + (radius * 0.3)
          G.line(pose.x + (Math.cos(angle) * from), pose.y + (Math.sin(angle) * from),
                 pose.x + (Math.cos(angle) * to), pose.y + (Math.sin(angle) * to))
        end
      end

      # A pale copy of the gamepad's reticle, and beside it the A button,
      # which goes down as it presses.
      def gamepad(pose, radius)
        alpha = pose.alpha * ALPHA
        look = pen.look::GAMEPAD
        pixels = pen.pixels
        ring(pose.x, pose.y, pose, radius * 0.3, radius * 0.9)
        [[palette.shadow, 0.6, 4], [palette.cream, 1.0, 2]].each do |color, strength, width|
          pen.color(color, alpha * strength)
          G.line_width = pixels.line_width(width)
          G.circle(:line, pose.x, pose.y, look.ring * radius, 48)
          [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
            G.line(pose.x + (dx * look.ticks.begin * radius), pose.y + (dy * look.ticks.begin * radius),
                   pose.x + (dx * look.ticks.end * radius), pose.y + (dy * look.ticks.end * radius))
          end
        end
        a_button(pixels.snap(pose.x + (radius * 0.8)), pixels.snap(pose.y - (radius * 0.8)), pose, radius, alpha)
      end

      def a_button(x, y, pose, radius, alpha)
        size = radius * 0.34 * (1 - (0.12 * pose.press))
        pen.color(palette.shadow, alpha * 0.7)
        G.circle(:fill, x, y + pen.pixels.line_width(2), size, 32)
        pen.color(palette.gain.mix(palette.cream, 0.35 * pose.press), alpha)
        G.circle(:fill, x, y, size, 32)
        font = pen.fonts.bold(Presentation::Pixels.font_size(radius * 0.42))
        pen.text("A", font, x, y, palette.ink_bottom, alpha)
        ring(x, y, pose, size, size * 2.0)
      end

      # A ring where a press lands, growing from +from+ to +to+ as it fades.
      def ring(x, y, pose, from, to)
        since = pose.since_press or return
        fade = 1 - (since / RING)
        return unless fade.positive?

        pen.color(palette.cream, pose.alpha * 0.6 * fade)
        G.line_width = pen.pixels.line_width(2)
        G.circle(:line, x, y, from + ((to - from) * Presentation::Ease.out_cubic(since / RING)), 48)
      end
    end
  end
end
