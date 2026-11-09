# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws dots bottom of the stack first, so the oldest dot is drawn
    # last, on top, each with its own shadow and halo in that same order:
    # a popped dot covers the halo of a fresh dot beneath it. Each dot is
    # drawn at its rule position; its pose only scales it about that
    # centre, and at rest it ends at its hit circle (Presentation::DotLook).
    #
    # With the dot shader, a dot is drawn from its geometry in one square.
    # Without it, plain circles keep the same distinction: a light disc
    # with a bright rim and a highlight for a fresh dot, a dark disc with a
    # rim and a crater for a popped one.
    class DotPainter < Data.define(:pen)
      G = ::Lota::Graphics
      SEGMENTS = 64

      def draw(stack, animations, now, radius)
        paint { stack.bottom_up.each { |dot| one(dot.x, dot.y, radius, animations.pose(dot, now), 1.0, dot.bonus?) } }
      end

      # What of the dots glows, for Bloom: the fresh dots alone. The glow
      # is drawn under every dot, so the dots above a fresh one hide its
      # light as they hide it.
      def glow(stack, animations, now, radius)
        paint do
          stack.bottom_up.each do |dot|
            pose = animations.pose(dot, now)
            one(dot.x, dot.y, radius, pose, pose.freshness, dot.bonus?) if pose.freshness.positive?
          end
        end
      end

      # One dot that is not in play, such as the title's examples.
      def icon(x, y, radius, fresh:, opacity: 1.0, bonus: false)
        paint { one(x, y, radius, fresh ? Presentation::Pose::FRESH : Presentation::Pose::STILL, opacity, bonus) }
      end

      # One plain dot in the colors of +palette+, whichever look is worn,
      # as the Looks screen shows each look's pair.
      def swatch(x, y, radius, palette, fresh:)
        G.push do
          G.translate(x, y)
          pen.color(palette.shadow, pen.style::DOT.shadow_alpha)
          G.circle(:fill, 0, radius * pen.style::DOT.shadow_offset, radius, SEGMENTS)
          fresh ? flat_fresh(radius, 1.0, palette) : flat_popped(radius, 1.0, palette)
        end
      end

      private

      def paint(&)
        return yield unless pen.shader?(:dot)

        pen.shading(:dot) { yield }
      end

      def one(x, y, radius, pose, opacity, bonus)
        pen.shader?(:dot) ? shaded(x, y, radius, pose, opacity, bonus) : flat(x, y, radius, pose, opacity, bonus)
      end

      def shaded(x, y, radius, pose, opacity, bonus)
        G.color = [pose.freshness, pose.alarm, bonus ? pose.freshness : 0.0, opacity]
        half = radius * pen.style::DOT.extent
        pen.square(x, y, half * pose.scale_x, half * pose.scale_y)
      end

      def flat(x, y, radius, pose, opacity, bonus)
        sizes = pen.style::DOT
        G.push do
          G.translate(x, y)
          G.scale(pose.scale_x, pose.scale_y)
          # A plain shadow has no soft edge, so it is the dot's own size,
          # only dropped: a crescent below, never a dark band all game.
          pen.color(pen.palette.shadow, sizes.shadow_alpha * opacity)
          G.circle(:fill, 0, radius * sizes.shadow_offset, radius, SEGMENTS)
          pose.freshness >= 0.5 ? flat_fresh(radius, opacity, bonus:) : flat_popped(radius, opacity)
          flat_alarm(radius, pose.alarm * opacity) if pose.alarm.positive?
        end
      end

      # The bright rim is the whole disc, and the body is drawn inside it,
      # so the dot's edge is its hit circle.
      def flat_fresh(radius, opacity, palette = pen.palette, bonus: false)
        rim, deep, body = (bonus ? palette.to_h.values_at(:bonus_rim, :bonus_deep, :bonus_body) : palette.to_h.values_at(:fresh_rim, :fresh_deep, :fresh_body))
        inner = radius - [radius * pen.style::DOT.rim, pen.pixels.line_width(2)].max
        pen.color(rim, opacity)
        G.circle(:fill, 0, 0, radius, SEGMENTS)
        pen.color(deep, opacity)
        G.circle(:fill, 0, 0, inner, SEGMENTS)
        pen.color(body, opacity)
        G.circle(:fill, -radius * 0.06, -radius * 0.08, inner * 0.88, SEGMENTS)
        pen.color(palette.gloss, 0.85 * opacity)
        G.ellipse(:fill, -radius * 0.36, -radius * 0.46, radius * 0.24, radius * 0.13, 32)
        flat_star(radius, opacity, palette) if bonus
      end

      # The bonus dot's mark: a dark four-pointed star, as the shader's, as
      # two crossed diamonds (a fill must be convex).
      def flat_star(radius, opacity, palette)
        pen.color(palette.bonus_mark, opacity)
        tip = radius * 0.58
        waist = radius * 0.13
        G.polygon(:fill, -tip, 0, 0, -waist, tip, 0, 0, waist)
        G.polygon(:fill, 0, -tip, waist, 0, 0, tip, -waist, 0)
      end

      def flat_popped(radius, opacity, palette = pen.palette)
        pen.color(palette.popped_rim, opacity)
        G.circle(:fill, 0, 0, radius, SEGMENTS)
        pen.color(palette.popped_top, opacity)
        G.circle(:fill, 0, 0, radius * 0.9, SEGMENTS)
        pen.color(palette.popped_lip, opacity)
        G.circle(:fill, radius * 0.03, radius * 0.04, radius * 0.5, SEGMENTS)
        pen.color(palette.popped_crater, opacity)
        G.circle(:fill, 0, 0, radius * 0.46, SEGMENTS)
      end

      def flat_alarm(radius, alpha)
        pen.color(pen.palette.alarm, alpha)
        G.line_width = radius * 0.12
        G.circle(:line, 0, 0, radius * 0.97, SEGMENTS)
      end
    end
  end
end
