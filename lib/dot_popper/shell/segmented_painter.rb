# frozen_string_literal: true

module DotPopper
  module Shell
    # A labelled segmented control, on whole device pixels: the title's
    # "Dot size". Its segments share one pill, each with a fresh dot drawn
    # at the size its option gives, then its option's name with what it
    # does here in smaller type under it, and the chosen one is filled, so
    # the choices, what each does, and which is chosen all show at a glance. The label sits to the left on the segments'
    # row, or above them when it has a row of its own. A segment the
    # mouse is over brightens and is outlined (Presentation::Hover).
    class SegmentedPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      # +choices+ are [name, note, chosen?, icon radius, hover], one for
      # each of the +control+'s options; +hover+ runs from 0 to 1.
      def draw(control, label, choices, alpha: 1.0)
        return if alpha <= 0.0

        frame = snapped(control.frame)
        widest = choices.map { it[3] }.max
        room = control.options.first.width - (frame.height * 0.5) - (widest * 2) - gap(frame.height)
        font = fit(choices.map(&:first), room, frame.height * NAME)
        note = fit(choices.map { it[1] }, room, frame.height * NOTE)
        label(label, font, control, alpha)
        backing(frame, alpha)
        control.options.zip(choices).each do |option, (name, words, chosen, icon, hover)|
          segment(snapped(option), [name, words], chosen, icon, [font, note], alpha, hover)
        end
      end

      # The name's and the note's type, as shares of a segment's height.
      NAME = 0.36
      NOTE = 0.27

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
      # words in ink; the other's are cream on the frame's dark. The icon
      # and the words are centred together, the note under the name.
      def segment(rect, (name, note), chosen, icon, (font, small), alpha, hover)
        palette = pen.palette
        inner = snapped(rect.inset(pen.pixels.snap(rect.height * 0.08)))
        corner = inner.height / 2.0
        if chosen
          pen.color(palette.cream, (0.92 + (0.08 * hover)) * alpha)
          G.rectangle(:fill, inner.x, inner.y, inner.width, inner.height, corner, corner, 48)
        end
        lit(inner, corner, chosen, hover * alpha) if hover.positive?
        pixels = pen.pixels
        radius = pixels.whole(icon)
        gap = gap(rect.height)
        words = [font.width(name), small.width(note)].max
        left = rect.center_x - (((radius * 2) + gap + words) / 2.0)
        dots.icon(pixels.snap(left + radius), pixels.snap(rect.center_y), radius, fresh: true, opacity: alpha)
        x = left + (radius * 2) + gap + (words / 2.0)
        top = rect.center_y - ((font.height + small.height) / 2.0)
        pen.text(name, font, x, top + (font.height / 2.0), chosen ? palette.ink_bottom : palette.cream, alpha)
        pen.text(note, small, x, top + font.height + (small.height / 2.0), chosen ? palette.ink_bottom : palette.soft,
                 alpha * (chosen ? 0.8 : 1.0))
      end

      # The mouse over a segment: the other choice's segment takes the
      # night's glow, and either is outlined.
      def lit(inner, corner, chosen, amount)
        style = pen.lit
        unless chosen
          pen.color(style.fill, style.fill.a * amount)
          G.rectangle(:fill, inner.x, inner.y, inner.width, inner.height, corner, corner, 48)
        end
        pen.color(style.edge, 0.8 * amount)
        G.line_width = pen.pixels.line_width(1)
        inset = pen.pixels.line_at(inner.x) - inner.x
        G.rectangle(:line, inner.x + inset, inner.y + inset, inner.width - (2 * inset), inner.height - (2 * inset),
                    corner, corner, 48)
      end

      # The space between a segment's icon and its name.
      def gap(height) = height * 0.14

      def snapped(rect)
        pixels = pen.pixels
        Presentation::Rect.new(x: pixels.snap(rect.x), y: pixels.snap(rect.y), width: pixels.snap(rect.width),
                               height: pixels.snap(rect.height))
      end

      # One size for every name, from +size+ units and shrunk by whole
      # sizes until the longest fits its segment.
      def fit(names, room, size)
        size = size.round
        size -= 1 while size > 10 && names.any? { pen.fonts.semibold(size).width(it) > room }
        pen.fonts.semibold(size)
      end
    end
  end
end
