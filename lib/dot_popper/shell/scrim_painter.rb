# frozen_string_literal: true

module DotPopper
  module Shell
    # A ScrimStyle drawn behind a rect of text: rounded rects in the night's
    # darkest ink, one inside the next, so the backing is darkest in the
    # middle and its edges feather out. Its outline is on whole device
    # pixels.
    class ScrimPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(rect, style, layout, alpha: 1.0)
        return if alpha <= 0.0

        pixels = pen.pixels
        pad = style.pad * layout.ui
        feather = style.feather * layout.ui
        outer = rect.inset(-pad - feather)
        pen.color(pen.palette.ink_edge, style.layer_alpha * alpha)
        style.insets(feather).each do |inset|
          box = outer.inset(inset)
          x, y, width, height = [box.x, box.y, box.width, box.height].map { pixels.snap(it) }
          corner = [pad + feather - inset, height / 2.0].min
          G.rectangle(:fill, x, y, width, height, corner, corner, 32)
        end
      end
    end
  end
end
