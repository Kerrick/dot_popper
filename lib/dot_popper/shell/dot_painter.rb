# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws dots with the dot shader, bottom of the stack first, so the
    # oldest dot is drawn last, on top. Each dot is drawn at its rule
    # position; its pose only scales it about that centre.
    class DotPainter
      FRESH = Presentation::Pose.new(scale_x: 1.0, scale_y: 1.0, freshness: 1.0, alarm: 0.0)

      def initialize(pen)
        @pen = pen
        @extent = pen.look::DOT.extent
      end

      def draw(stack, animations, now, radius, opacity: 1.0)
        @pen.shading(:dot) do
          stack.bottom_up.each { |dot| draw_pose(dot.x, dot.y, radius, animations.pose(dot, now), opacity) }
        end
      end

      # One dot that is not in play, such as the title's examples.
      def icon(x, y, radius, fresh:, opacity: 1.0)
        pose = fresh ? FRESH : Presentation::Pose::STILL
        @pen.shading(:dot) { draw_pose(x, y, radius, pose, opacity) }
      end

      private

      def draw_pose(x, y, radius, pose, opacity)
        ::Lota::Graphics.color = [pose.freshness, pose.alarm, 0.0, opacity]
        half = radius * @extent
        @pen.square(x, y, half * pose.scale_x, half * pose.scale_y)
      end
    end
  end
end
