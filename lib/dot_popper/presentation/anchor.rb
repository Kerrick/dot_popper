# frozen_string_literal: true

module DotPopper
  module Presentation
    # A place the Tutorial points at: a dot, followed by its id wherever it
    # goes; the HUD's score or time (+name+ :score or :time), +below+ radii
    # under the middle of its number; or a fixed point. Only the shell can
    # measure where the HUD's numbers are drawn, so it says where they are
    # (#point's +spots+), and the tutorial teaches at their real places.
    class Anchor < Data.define(:kind, :name, :x, :y)
      def self.dot(id) = new(kind: :dot, name: id, x: 0.0, y: 0.0)
      def self.hud(name, below: 0.0) = new(kind: :hud, name:, x: 0.0, y: below)
      def self.at(x, y) = new(kind: :point, name: nil, x: x.to_f, y: y.to_f)

      def hud? = kind == :hud

      # Where it is, as [x, y]: among +dots+ (a Stack), or in the HUD,
      # whose numbers' middles +spots+ gives by name, with dots of
      # +radius+. Nil for a dot that is not there.
      def point(dots, spots, radius)
        case kind
        in :dot then dots.find { it.id == name }&.then { [it.x, it.y] }
        in :hud then spots.fetch(name).then { |spot_x, spot_y| [spot_x, spot_y + (y * radius)] }
        in :point then [x, y]
        end
      end
    end
  end
end
