# frozen_string_literal: true

module DotPopper
  module Shell
    # The share preview, over Game Over and its HUD, where the Show's
    # SharePlan puts it: the screen veiled behind a dark card, "Share your
    # score", the result in a message bubble, left-aligned as it will read
    # when pasted, its emoji drawn as the game's own dots and a stopwatch,
    # "Copied! Paste it anywhere." with a check once Copy has copied it,
    # and Close beside Copy, the card's one
    # filled gold button. It lifts into place as it fades in.
    class SharePreviewPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      # Draws what the screen hands it (Presentation::ShareDrawing), over a
      # veil +width+ by +height+.
      def draw(drawing, width, height)
        shown = drawing.shown
        veil(width, height, drawing.veil)
        plan = drawing.plan
        G.push do
          G.translate(0, pen.pixels.snap(drawing.lift))
          card(plan.card, drawing.corner, shown)
          heading(drawing, plan, shown)
          message(drawing, plan, shown)
          note(drawing, plan, shown)
          PillButton.new(pen:).draw(plan.close, drawing.close, alpha: shown, hover: drawing.close_hover)
          PrimaryButton.new(pen:).draw(plan.copy, drawing.copy, alpha: shown, hover: drawing.copy_hover,
                                         ratio: PillButton::LABEL)
        end
      end

      private

      def veil(width, height, alpha)
        pen.color(pen.palette.ink_bottom, alpha)
        G.rectangle(:fill, 0, 0, width, height)
      end

      def card(rect, corner, alpha)
        palette = pen.palette
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        pen.color(palette.ink_top, 0.97 * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 48)
        pen.color(palette.soft, 0.35 * alpha)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(x) - x
        G.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 48)
      end

      def heading(drawing, plan, alpha)
        rect = plan[:heading] or return

        pen.text(drawing.heading, pen.fonts.bold(plan.size(:heading)), rect.center_x, rect.center_y,
                 pen.palette.cream, alpha)
      end

      # The result's lines, in a bubble of the night's darkest ink.
      def message(drawing, plan, alpha)
        rect = plan[:message]
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        bubble = plan.bubble
        pen.color(pen.palette.ink_bottom, 0.9 * alpha)
        G.rectangle(:fill, x, y, width, height, bubble, bubble, 32)
        font = pen.fonts.semibold(plan.size(:message))
        step = font.height * Presentation::ShareScreen::LINE
        drawing.runs.each_with_index do |runs, i|
          runs(runs, font, x + plan.side, y + bubble + (font.height / 2.0) + (step * i), alpha)
        end
      end

      # One line's runs, left to right: its words, and a shape for each emoji.
      def runs(runs, font, x, y, alpha)
        room = font.height * Presentation::ShareGlyphs::WIDTH
        runs.each do |run|
          if run.is_a?(Symbol)
            glyph(run, x + (room / 2.0), y, font.height * 0.34, alpha)
            x += room
          else
            pen.text(run, font, x + (font.width(run) / 2.0), y, pen.palette.cream, alpha)
            x += font.width(run)
          end
        end
      end

      def glyph(name, x, y, radius, alpha)
        case name
        in :bright then dots.icon(x, y, radius, bright: true, opacity: alpha)
        in :popped then dots.icon(x, y, radius, bright: false, opacity: alpha)
        in :clock then stopwatch(x, y, radius, alpha)
        end
      end

      # A stopwatch: a ring, a hand, and the button on top.
      def stopwatch(x, y, radius, alpha)
        pixels = pen.pixels
        pen.color(pen.palette.soft, alpha)
        G.line_width = pixels.whole(radius * 0.22)
        G.circle(:line, x, y + (radius * 0.1), radius * 0.85, 32)
        G.line(x, y + (radius * 0.1), x + (radius * 0.4), y - (radius * 0.3))
        G.rectangle(:fill, x - (radius * 0.25), y - (radius * 1.1), radius * 0.5, radius * 0.25)
      end

      # Once Copy has copied: "Copied! Paste it anywhere.", with a check,
      # fading in where the plan keeps room for it.
      def note(drawing, plan, alpha)
        copied = drawing.copied
        return unless copied.positive?

        rect = plan[:note]
        font = pen.fonts.semibold(plan.size(:note))
        CheckMark.new(pen:).labeled(drawing.copied_word, font, rect.center_x, rect.center_y, alpha * copied)
      end
    end
  end
end
