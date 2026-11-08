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
        paint { stack.bottom_up.each { |dot| one(dot.x, dot.y, radius, animations.pose(dot, now), 1.0) } }
      end

      # What of the dots glows, for Bloom: the fresh dots alone. The glow
      # is drawn under every dot, so the dots above a fresh one hide its
      # light as they hide it.
      def glow(stack, animations, now, radius)
        paint do
          stack.bottom_up.each do |dot|
            pose = animations.pose(dot, now)
            one(dot.x, dot.y, radius, pose, pose.freshness) if pose.freshness.positive?
          end
        end
      end

      # One dot that is not in play, such as the title's examples.
      def icon(x, y, radius, fresh:, opacity: 1.0)
        paint { one(x, y, radius, fresh ? Presentation::Pose::FRESH : Presentation::Pose::STILL, opacity) }
      end

      private

      def paint(&)
        return yield unless pen.shader?(:dot)

        pen.shading(:dot) { yield }
      end

      def one(x, y, radius, pose, opacity)
        pen.shader?(:dot) ? shaded(x, y, radius, pose, opacity) : flat(x, y, radius, pose, opacity)
      end

      def shaded(x, y, radius, pose, opacity)
        G.color = [pose.freshness, pose.alarm, 0.0, opacity]
        half = radius * pen.look::DOT.extent
        pen.square(x, y, half * pose.scale_x, half * pose.scale_y)
      end

      def flat(x, y, radius, pose, opacity)
        sizes = pen.look::DOT
        G.push do
          G.translate(x, y)
          G.scale(pose.scale_x, pose.scale_y)
          # A plain shadow has no soft edge, so it is the dot's own size,
          # only dropped: a crescent below, never a dark band all round.
          pen.color(pen.palette.shadow, sizes.shadow_alpha * opacity)
          G.circle(:fill, 0, radius * sizes.shadow_offset, radius, SEGMENTS)
          pose.freshness >= 0.5 ? flat_fresh(radius, opacity) : flat_popped(radius, opacity)
          flat_alarm(radius, pose.alarm * opacity) if pose.alarm.positive?
        end
      end

      # The bright rim is the whole disc, and the body is drawn inside it,
      # so the dot's edge is its hit circle.
      def flat_fresh(radius, opacity)
        palette = pen.palette
        inner = radius - [radius * pen.look::DOT.rim, pen.pixels.line_width(2)].max
        pen.color(palette.fresh_rim, opacity)
        G.circle(:fill, 0, 0, radius, SEGMENTS)
        pen.color(palette.fresh_deep, opacity)
        G.circle(:fill, 0, 0, inner, SEGMENTS)
        pen.color(palette.fresh_body, opacity)
        G.circle(:fill, -radius * 0.06, -radius * 0.08, inner * 0.88, SEGMENTS)
        pen.color(palette.gloss, 0.85 * opacity)
        G.ellipse(:fill, -radius * 0.36, -radius * 0.46, radius * 0.24, radius * 0.13, 32)
      end

      def flat_popped(radius, opacity)
        palette = pen.palette
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
