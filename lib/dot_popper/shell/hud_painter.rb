# frozen_string_literal: true

module DotPopper
  module Shell
    # The score and the time left, in a translucent pill at the top of the
    # safe area, over every dot. A number that changes bumps by drawing in
    # a bigger font for a moment; glyphs are never stretched.
    class HudPainter < Data.define(:pen)
      G = ::Lota::Graphics
      BUMP_STEP = 2 # font sizes a bump steps through, in graphics units

      def draw(hud, layout)
        type = pen.look::TYPE
        number = pen.fonts.bold(layout.scaled(type.hud_number))
        label = pen.fonts.semibold(layout.scaled(type.hud_label))
        readouts = [hud.score_readout, hud.time_readout]
        pad = number.height * 0.32
        cell = readouts.map { [number.width(it.text), number.width("00"), label.width(it.label)].max }.max + (pad * 2.4)
        height = label.height + (number.height * 0.9) + pad
        pill = pill(layout.center_x - cell, layout.top, cell * 2, height)
        readouts.each_with_index do |readout, i|
          readout(readout, pill.x + (cell * (i + 0.5)), pill.y + (pad * 0.55), number, label, layout)
        end
        divider(pill.x + cell, pill.y + (pad * 0.7), pill.bottom - (pad * 0.7))
      end

      # Makes every size a bump or an urgent pulse passes through, an
      # elastic one's undershoot included, before the first number changes.
      def prepare(layout)
        hud = pen.look::HUD
        size = layout.scaled(pen.look::TYPE.hud_number)
        largest = [hud.bump.from, hud.pulse.from].max
        largest.step(0.85, -0.01) { pen.fonts.bold(Presentation::Pixels.font_size(size * it, step: BUMP_STEP)) }
      end

      private

      def pill(x, y, width, height)
        pixels = pen.pixels
        rect = Presentation::Rect.new(x: pixels.snap(x), y: pixels.snap(y), width: pixels.snap(width),
                                      height: pixels.snap(height))
        corner = rect.height / 2.0
        pen.color(pen.palette.pill)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 48)
        pen.color(pen.palette.pill_edge)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(rect.x) - rect.x
        G.rectangle(:line, rect.x + inset, rect.y + inset, rect.width - (2 * inset), rect.height - (2 * inset),
                    corner, corner, 48)
        rect
      end

      def divider(x, top, bottom)
        pixels = pen.pixels
        pen.color(pen.palette.pill_edge)
        G.line_width = pixels.line_width(1)
        at = pixels.line_at(x)
        G.line(at, pixels.snap(top), at, pixels.snap(bottom))
      end

      def readout(readout, x, top, number, label, layout)
        palette = pen.palette
        pen.text(readout.label, label, x, top + (label.height / 2.0), palette.soft)
        center = top + label.height + (number.height * 0.42)
        size = Presentation::Pixels.font_size(layout.scaled(pen.look::TYPE.hud_number) * readout.scale, step: BUMP_STEP)
        color = palette.cream.mix(palette.urgent, readout.urgency)
        pen.text(readout.text, pen.fonts.bold(size), x, center, color)
      end
    end
  end
end
