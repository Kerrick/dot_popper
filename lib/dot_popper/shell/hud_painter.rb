# frozen_string_literal: true

module DotPopper
  module Shell
    # The score and the time left, in a see-through pill at the top of the
    # safe area, over every dot, outlined so they stay crisp over one. A number that changes bumps by drawing in
    # a bigger font for a moment; glyphs are never stretched.
    class HudPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      # Draws +drawing+ (Presentation::HudDrawing) and answers the pill.
      def draw(drawing)
        plan = drawing.plan
        number, label = fonts(plan)
        pad = plan.pad
        cell = plan.cell
        pill = pill(bounds(drawing))
        drawing.readouts.each_with_index do |readout, i|
          readout(readout, drawing.sizes[i], pill.x + (cell * (i + 0.5)), pill.y + (pad * 0.55), number, label)
        end
        divider(pill.x + cell, pill.y + (pad * 0.7), pill.bottom - (pad * 0.7))
        dots_in_a_row(drawing.dots_in_a_row, pill) if drawing.dots_in_a_row
        pill
      end

      # Where the pill goes, on whole device pixels, without drawing it.
      def bounds(drawing)
        plan = drawing.plan
        pixels = pen.pixels
        Presentation::Rect.new(x: pixels.snap(plan.center_x - plan.cell), y: pixels.snap(plan.top),
                               width: pixels.snap(plan.cell * 2), height: pixels.snap(plan.height))
      end

      # Where the middles of the score's and the time's numbers are drawn,
      # as [x, y] by name, for the Tutorial to point at.
      def spots(drawing)
        plan = drawing.plan
        cell = plan.cell
        rect = bounds(drawing)
        y = number_middle(rect.y + (plan.pad * 0.55), plan)
        { score: [rect.x + (cell * 0.5), y], time: [rect.x + (cell * 1.5), y],
          dots_in_a_row: [rect.center_x, dots_in_a_row_top(rect)] }
      end

      # Makes every size a bump or an urgent pulse passes through, an
      # elastic one's undershoot included, before the first number changes.
      def prepare(layout)
        hud = pen.style::HUD
        size = layout.scaled(pen.style::TYPE.hud_number)
        largest = [hud.bump.from, hud.pulse.from].max
        largest.step(0.85, -0.01) { pen.fonts.bold(Presentation::Pixels.font_size(size * it, step: Presentation::Hud::BUMP_STEP)) }
      end

      private

      # The row toward a bonus dot, as a row of the game's own small
      # dots hung under the pill: bright ones are the dots popped so far, dark
      # ones are still to come, and all of them mint when the bonus dot is
      # out there to pop.
      def dots_in_a_row(readout, pill)
        pixels = pen.pixels
        radius = pill.height * Presentation::Hud::PIP
        step = radius * Presentation::Hud::PIP_STEP
        left = pill.center_x - (step * (readout.size - 1) / 2.0)
        top = dots_in_a_row_top(pill)
        readout.size.times do |i|
          grown = readout.bumping?(i) ? radius * readout.scale : radius
          dots.icon(pixels.snap(left + (step * i)), pixels.snap(top), grown, bright: readout.lit?(i),
                                                                       bonus: readout.ready, opacity: 0.95)
        end
      end

      # The middle of the row's row of dots, hung under the +pill+.
      def dots_in_a_row_top(pill) = pill.bottom + (pill.height * Presentation::Hud::PIP * 1.7)

      def fonts(plan) = [pen.fonts.bold(plan.number_size), pen.fonts.semibold(plan.label_size)]

      # The middle of a readout's number, under its label, from the top of
      # the readout.
      def number_middle(top, plan) = top + plan.label_height + (plan.number_height * 0.42)

      def pill(rect)
        pixels = pen.pixels
        corner = rect.height / 2.0
        pen.color(pen.palette.pill, pen.style::HUD.backing)
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

      def readout(readout, size, x, top, number, label)
        palette = pen.palette
        pen.outlined(readout.label, label, x, top + (label.height / 2.0), palette.soft)
        center = top + label.height + (number.height * 0.42)
        color = palette.cream.mix(palette.urgent, readout.urgency)
        pen.outlined(readout.text, pen.fonts.bold(size), x, center, color)
      end
    end
  end
end
