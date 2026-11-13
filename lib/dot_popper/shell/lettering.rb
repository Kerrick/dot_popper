# frozen_string_literal: true

module DotPopper
  module Shell
    # Big display words set like candy: light letters on a deeper,
    # extruded copy of themselves, every layer on whole device pixels.
    class Lettering < Data.define(:pen)
      def candy(text, font, x, y, alpha = 1.0, face: pen.palette.bright_light, side: pen.palette.bright_deep)
        depth = [(font.height * 0.06 * pen.pixels.scale).round, 1].max
        depth.downto(1) { |step| pen.text(text, font, x, y + (step / pen.pixels.scale), side, alpha) }
        pen.text(text, font, x, y, face, alpha)
      end
    end
  end
end
