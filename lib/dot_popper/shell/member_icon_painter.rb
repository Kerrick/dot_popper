# frozen_string_literal: true

module DotPopper
  module Shell
    # A Presentation::MemberIcon drawn at +radius+ around +x+, +y+. The
    # stars are drawn fan by fan, since LÖVE fills only convex polygons.
    class MemberIconPainter < Data.define(:pen, :icons)
      G = ::Lota::Graphics

      def initialize(pen:, icons: {}) = super

      def draw(x, y, radius, group_id, number, alpha = 1.0)
        icon = fetch([group_id, number]) { Presentation::MemberIcon.of(group_id, number) }
        paint(icon, x, y, radius, alpha)
      end

      def crest(x, y, radius, group_id, alpha = 1.0)
        icon = fetch([group_id, :crest]) { Presentation::MemberIcon.crest(group_id) }
        paint(icon, x, y, radius, alpha)
      end

      private

      def fetch(key) = icons[key] ||= yield

      def paint(icon, x, y, radius, alpha)
        pen.color(icon.base, alpha)
        G.circle(:fill, x, y, radius, 48)
        icon.shapes.each do |shape|
          pen.color(icon.color(shape.tone), alpha)
          case shape
          in Presentation::IconDot then G.circle(:fill, x + (shape.x * radius), y + (shape.y * radius), shape.r * radius, 24)
          in Presentation::IconShape then fill(shape.points, x, y, radius)
          end
        end
      end

      # A shape as a fan of triangles from its own centre, which suits the
      # convex motifs and the concave star alike.
      def fill(points, x, y, radius)
        placed = points.each_slice(2).map { |px, py| [x + (px * radius), y + (py * radius)] }
        cx = placed.sum(&:first) / placed.size
        cy = placed.sum(&:last) / placed.size
        placed.each_with_index do |(ax, ay), i|
          bx, by = placed[(i + 1) % placed.size]
          G.polygon(:fill, cx, cy, ax, ay, bx, by)
        end
      end
    end
  end
end
