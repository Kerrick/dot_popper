# frozen_string_literal: true

module DotPopper
  module Shell
    # A labelled segmented control, on whole device pixels: the title's
    # "Dot size". Its segments share one pill, each with a fresh dot drawn
    # at the size its option gives, then its option's name, and the chosen
    # one is filled, so the choices, what each does, and which is chosen
    # all show at a glance. The label sits to the left on the segments'
    # row, or above them when it has a row of its own.
    class SegmentedPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      # +choices+ are [name, chosen?, icon radius] triples, one for each
      # of the +control+'s options.
      def draw(control, label, choices, alpha: 1.0)
        return if alpha <= 0.0

        frame = snapped(control.frame)
        widest = choices.map(&:last).max
        room = control.options.first.width - (frame.height * 0.5) - (widest * 2) - gap(frame.height)
        font = fit(choices.map(&:first), room, frame.height)
        label(label, font, control, alpha)
        backing(frame, alpha)
        control.options.zip(choices).each do |option, (name, chosen, icon)|
          segment(snapped(option), name, chosen, icon, font, alpha)
        end
      end

      private

      def label(text, font, control, alpha)
        box = control.label
        beside = box.y == control.frame.y
        x = beside ? box.right - (font.height * 0.5) - (font.width(text) / 2.0) : box.center_x
        pen.text(text, font, x, box.center_y, pen.palette.soft, alpha)
      end

      def backing(frame, alpha)
        palette = pen.palette
        pixels = pen.pixels
        corner = frame.height / 2.0
        pen.color(palette.pill, palette.pill.a * alpha)
        G.rectangle(:fill, frame.x, frame.y, frame.width, frame.height, corner, corner, 48)
        pen.color(palette.soft, 0.55 * alpha)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(frame.x) - frame.x
        G.rectangle(:line, frame.x + inset, frame.y + inset, frame.width - (2 * inset), frame.height - (2 * inset),
                    corner, corner, 48)
      end

      # The chosen segment is a lighter pill inside the frame, with its
      # name in ink; the other's name is cream on the frame's dark. The
      # icon and the name are centred together.
      def segment(rect, name, chosen, icon, font, alpha)
        palette = pen.palette
        if chosen
          inner = snapped(rect.inset(pen.pixels.snap(rect.height * 0.08)))
          corner = inner.height / 2.0
          pen.color(palette.cream, 0.92 * alpha)
          G.rectangle(:fill, inner.x, inner.y, inner.width, inner.height, corner, corner, 48)
        end
        pixels = pen.pixels
        radius = pixels.whole(icon)
        gap = gap(rect.height)
        left = rect.center_x - (((radius * 2) + gap + font.width(name)) / 2.0)
        dots.icon(pixels.snap(left + radius), pixels.snap(rect.center_y), radius, fresh: true, opacity: alpha)
        pen.text(name, font, left + (radius * 2) + gap + (font.width(name) / 2.0), rect.center_y,
                 chosen ? palette.ink_bottom : palette.cream, alpha)
      end

      # The space between a segment's icon and its name.
      def gap(height) = height * 0.14

      def snapped(rect)
        pixels = pen.pixels
        Presentation::Rect.new(x: pixels.snap(rect.x), y: pixels.snap(rect.y), width: pixels.snap(rect.width),
                               height: pixels.snap(rect.height))
      end

      # One size for every name, shrunk by whole sizes until the longest
      # fits its segment.
      def fit(names, room, height)
        size = (height * 0.4).round
        size -= 1 while size > 10 && names.any? { pen.fonts.semibold(size).width(it) > room }
        pen.fonts.semibold(size)
      end
    end
  end
end
