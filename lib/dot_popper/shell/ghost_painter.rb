# frozen_string_literal: true

module DotPopper
  module Shell
    # The Tutorial's ghost hand, drawn as the player's own hand on the
    # input they last used (Presentation::InputKind): a pointing hand for
    # a touchscreen, a mouse pointer that clicks, or a gamepad's reticle
    # with its A button beside it. The pointer and the reticle are pale and
    # see-through, so the dot under them shows; the hand, the pointing
    # emoji, touches the dot only with its fingertip, and is solid. Each
    # press rings where it lands. Its letter and its tip sit on whole
    # device pixels.
    class GhostPainter < Data.define(:pen)
      G = ::Lota::Graphics
      ALPHA = 0.85 # how much of the pointer and the reticle show at most
      RING = 0.4 # seconds a press's ring lasts
      RIPPLE = 0.45 # seconds a tap's ripple lasts, before the hand lifts away
      HAND = 3.0 # the pointing hand's picture's side, in the dot's radius

      # A pointer's outline, its tip at 0, 0, in twentieths of its height.
      ARROW = [[0, 0], [0, 17], [4, 13], [7, 20], [10, 19], [7, 12], [12, 12]].freeze
      # ...filled as convex pieces: a fan from the tip, and the tail.
      PIECES = [[0, 1, 2], [0, 2, 5], [0, 5, 6], [2, 3, 4, 5]].freeze

      # The hand for +input+ at +pose+, sized for a dot of +radius+, kept
      # on a screen +width+ by +height+ (the window's, unless given).
      def draw(pose, input, radius, screen: G.dimensions)
        return unless pose && pose.alpha.positive?

        case input.name
        in :touch then hand(pose, radius, screen)
        in :mouse then pointer(pose, radius)
        in :gamepad then gamepad(pose, radius)
        end
      end

      private

      def palette = pen.palette

      # The pointing hand emoji (Presentation::PointingHand), upright, its
      # fingertip on the point it taps and the hand below it, mirrored
      # where the right edge would cut it off. It is the smallest of its
      # PNGs with at least the pixels it needs, drawn a little smaller with
      # its mipmaps. As it presses, it sinks a little smaller, as if pushed
      # into the glass, and a ripple spreads from its fingertip.
      def hand(pose, radius, screen)
        pixels = pen.pixels
        x = pixels.snap(pose.x)
        y = pixels.snap(pose.y)
        ripple(x, y, pose, radius)
        art = Presentation::PointingHand
        side = radius * HAND * (1 - (art::PRESS * pose.press))
        across = art.facing(x, radius * HAND, screen.first)
        sprite = pen.hands.for(side * pixels.scale)
        scale = side / sprite.height
        (tip_x, tip_y), (wrist_x, wrist_y) = art::TIP_AT, art::WRIST_AT
        G.color = [1, 1, 1, pose.alpha]
        G.draw(sprite, x + (across * (wrist_x - tip_x) * side), y + ((wrist_y - tip_y) * side), 0,
               across * scale, scale, wrist_x * sprite.width, wrist_y * sprite.height)
      end

      # A tap's ripple: two thin rings spreading from where the fingertip
      # lands, past the dot's edge, gone before the hand lifts away.
      def ripple(x, y, pose, radius)
        since = pose.since_press or return
        G.line_width = pen.pixels.line_width([radius * pen.pixels.scale * 0.06, 2].max)
        [[0.0, 1.0], [0.06, 0.6]].each do |delay, strength|
          share = (since - delay) / (RIPPLE - delay)
          next unless share.between?(0.0, 1.0)

          pen.color(palette.cream, pose.alpha * strength * (1 - share))
          G.circle(:line, x, y, radius * (0.4 + (1.2 * Presentation::Ease.out_cubic(share))), 48)
        end
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
