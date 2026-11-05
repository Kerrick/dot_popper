# frozen_string_literal: true

module DotPopper
  module Shell
    # The Records screen, over the title's dimmed dots: the heading, the
    # chart of the last scores, the bests and totals as rows with their
    # labels on the left and their numbers lined up on the right, and the
    # prompt to go back. Presentation::RecordsLayout decides where each
    # goes; this only draws, on whole device pixels.
    class RecordsPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        sheet = show.records or return
        words = show.words
        palette = pen.palette
        plan = Presentation::RecordsLayout.new(layout:, sheet:, look: pen.look::RECORDS)
        pen.text(words.records, pen.fonts.bold(plan.heading_size), layout.center_x, plan.heading_y, palette.cream)
        pen.text(words.go_back, pen.fonts.bold(plan.prompt_size), layout.center_x, plan.prompt_y, palette.cream,
                 show.marquee.prompt(show.now))
        return nothing_yet(words, layout, plan) if sheet.empty

        size = fit(plan)
        plan.placements.each { place(it, sheet, size) }
      end

      private

      def nothing_yet(words, layout, plan)
        pen.text(words.no_rounds, pen.fonts.semibold(plan.text_size), layout.center_x, layout.center_y, pen.palette.soft)
      end

      # The rows' type size, shrunk by whole sizes until every row's label
      # and number fit across its column with room between them.
      def fit(plan)
        rows = plan.placements.select { it.item.is_a?(Presentation::RecordRow) }
        size = plan.text_size
        size -= 1 while size > Presentation::RecordsLayout::SMALLEST_TEXT && rows.any? { !fits?(it, size) }
        size
      end

      def fits?(placed, size)
        row = placed.item
        pen.fonts.semibold(size).width(row.label) + pen.fonts.bold(size).width(row.value) + (size * 1.5) <= placed.width
      end

      def place(placed, sheet, size)
        palette = pen.palette
        case placed.item
        in String => title then left(title, pen.fonts.bold(size), placed.x, placed.y, palette.gain)
        in Presentation::RecordRow => row
          left(row.label, pen.fonts.semibold(size), placed.x, placed.y, palette.soft)
          right(row.value, pen.fonts.bold(size), placed.right, placed.y, palette.cream)
        in :chart then chart(sheet.scores, placed, size)
        end
      end

      def left(text, font, x, y, color) = pen.text(text, font, x + (font.width(text) / 2.0), y, color)
      def right(text, font, x, y, color) = pen.text(text, font, x - (font.width(text) / 2.0), y, color)

      # The last scores as bars on a faint baseline, the best of them
      # brighter and labelled with its score. The chart's title, above it,
      # is placed as a section's is.
      def chart(scores, placed, size)
        palette = pen.palette
        pixels = pen.pixels
        label = pen.fonts.bold(size)
        box = Presentation::Rect.new(x: placed.x, y: placed.y + label.height, width: placed.width,
                                     height: placed.height - label.height)
        bars = Presentation::ScoreBars.new(scores:).bars(box, pixels)
        bars.each do |bar|
          pen.color(palette.fresh_body, bar.best ? 1.0 : 0.5)
          corner = [bar.width / 2.0, 2 / pixels.scale].min
          G.rectangle(:fill, bar.x, bar.y, bar.width, bar.height, corner, corner, 8)
        end
        baseline(box)
        best = bars.find(&:best)
        pen.text(best.score.to_s, label, best.x + (best.width / 2.0), best.y - (label.height * 0.6), palette.cream) if best
      end

      def baseline(box)
        pixels = pen.pixels
        pen.color(pen.palette.soft, 0.35)
        G.line_width = pixels.line_width(1)
        y = pixels.line_at(box.bottom)
        G.line(pixels.snap(box.x), y, pixels.snap(box.right), y)
      end
    end
  end
end
