# frozen_string_literal: true

module DotPopper
  module Shell
    # A theme's night, baked once for the screen's size into a canvas at
    # the screen's own resolution and then drawn each frame 1:1, so scenery
    # costs one quad on an old phone: the sky by shader, the silhouettes by
    # plain polygons, then fog by the shader over them.
    class Scene
      G = ::Lota::Graphics

      def initialize(pen)
        @pen = pen
      end

      # Whether there is a baked night to draw.
      def on? = !@canvas.nil?

      # Bakes +art+ for the screen, or forgets it for the ordinary night.
      def bake(art)
        @canvas = nil
        return unless art&.sky && @pen.shader?(:scene)

        width, height = G.dimensions
        @canvas = G::Canvas.new(width, height, dpiscale: G.dpi_scale)
        G.push(:all) do
          G.origin
          G.canvas = @canvas
          G.clear(0, 0, 0, 1)
          sky(art.sky, width, height, 0.0)
          shapes(Presentation::Scenery.for(art.scenery, width, height))
          sky(art.sky, width, height, 1.0) if art.sky.fog_amount.positive?
          G.canvas = nil
        end
      rescue StandardError => e
        warn "Dot Popper: drawing without the scenery (#{e.message})"
        @canvas = nil
      end

      def draw
        G.color = [1, 1, 1, 1]
        G.blend_mode = %i[replace premultiplied]
        G.draw(@canvas, 0, 0)
        G.blend_mode = :alpha
      end

      private

      def sky(sky, width, height, pass)
        @pen.shading(:scene) do |shader|
          @pen.uniform(shader, "pass", pass)
          @pen.uniform(shader, "size", [width.to_f, height.to_f])
          sky.to_h.each do |name, value|
            @pen.uniform(shader, name.to_s, value.respond_to?(:r) ? @pen.rgb(value) : value)
          end
          G.color = [1, 1, 1, 1]
          @pen.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      def shapes(list)
        list.each do |shape|
          @pen.color(shape.color)
          case shape
          in Presentation::Scenery::Dot then G.circle(:fill, shape.x, shape.y, shape.radius, 16)
          in Presentation::Scenery::Fan then fan(shape.points)
          end
        end
      end

      def fan(points)
        hub = points.first
        points[1..].each_cons(2) { |a, b| G.polygon(:fill, *hub, *a, *b) }
      end
    end
  end
end
