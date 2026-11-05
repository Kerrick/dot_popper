# frozen_string_literal: true

module DotPopper
  module Presentation
    # One line of the Records screen: what it counts, and how many.
    class RecordRow < Data.define(:label, :value); end

    # A titled group of RecordRows.
    class RecordSection < Data.define(:title, :rows); end

    # What the Records screen says, worked out from LifetimeStats and the
    # best score: the player's bests, their totals, and the last few
    # scores for the chart. With no round played yet, +empty+ is true and
    # there is nothing to list.
    class RecordsSheet < Data.define(:bests, :totals, :scores, :empty)
      def self.build(stats, best:, words:)
        labels = words.labels
        bests = RecordSection.new(title: labels[:bests], rows: [
          RecordRow.new(label: labels[:best_score], value: best.to_s),
          RecordRow.new(label: labels[:longest_round], value: Words.count(stats.longest_round.round, "second")),
          RecordRow.new(label: labels[:longest_run], value: stats.longest_run.to_s),
          RecordRow.new(label: labels[:fastest_pop], value: words.seconds_or_none(stats.fastest_pop)),
          RecordRow.new(label: labels[:longest_wait], value: words.seconds_or_none(stats.longest_wait))
        ])
        totals = RecordSection.new(title: labels[:totals], rows: [
          RecordRow.new(label: labels[:rounds], value: stats.rounds.to_s),
          RecordRow.new(label: labels[:pops], value: stats.pops.to_s),
          RecordRow.new(label: labels[:slips], value: stats.slips.to_s),
          RecordRow.new(label: labels[:seconds], value: Words.duration(stats.seconds)),
          RecordRow.new(label: labels[:days], value: stats.days.to_s)
        ])
        new(bests:, totals:, scores: stats.recent, empty: stats.rounds.zero?)
      end
    end

    # One bar of the score chart, on whole device pixels; +best+ marks the
    # highest score shown.
    class ScoreBar < Data.define(:x, :y, :width, :height, :score, :best); end

    # The last scores as bars, oldest on the left, in +slots+ places of
    # equal width so the chart fills up as rounds are played. Bars stand
    # on the bottom of their rect, as tall as their score against the
    # highest; a round of 0 still shows a stub one device pixel high.
    class ScoreBars < Data.define(:scores, :slots)
      def initialize(scores:, slots: LifetimeStats::RECENT) = super

      def bars(rect, pixels)
        highest = scores.max || 0
        best = scores.rindex(highest)
        slot = rect.width / slots
        gap = pixels.whole([slot * 0.22, 2 / pixels.scale].max)
        bottom = pixels.snap(rect.bottom)
        scores.each_with_index.map do |score, i|
          left = pixels.snap(rect.x + (i * slot))
          tall = highest.positive? ? pixels.whole(rect.height * score / highest) : pixels.whole(0)
          ScoreBar.new(x: left, y: bottom - tall, width: pixels.snap(rect.x + ((i + 1) * slot)) - left - gap,
                       height: tall, score:, best: i == best)
        end
      end
    end

    # Where a part of the Records screen goes: +item+ is a section's title
    # or the chart's (a String), a RecordRow, or :chart. A text line is
    # centred on +y+; the chart's box starts at +y+ and is +height+ tall.
    class Placed < Data.define(:item, :x, :y, :width, :height)
      def right = x + width
    end

    # Sizes for the Records screen, in graphics units at a scale of 1:
    # the heading's and the rows' type, a row's height as a multiple of
    # its type, the chart's height in rows, the gap between two columns,
    # a column's widest, and how dark the title's dots are behind it.
    class RecordsLook < Data.define(:heading, :text, :line, :chart, :gap, :column, :veil); end

    # The Records screen laid out in the safe area: the heading at the
    # top, the prompt to go back at the bottom, and between them the
    # chart and the sections. A wide screen puts the bests on the left
    # and the chart and totals on the right; a narrow one stacks them. Rows shrink, never below a readable size,
    # to fit a short screen.
    class RecordsLayout < Data.define(:layout, :sheet, :look)
      SMALLEST_TEXT = 11

      def heading_size = layout.scaled(look.heading)
      def heading_y = layout.top + (heading_size * 0.6)
      def prompt_size = layout.scaled(Look::TYPE.prompt)
      def prompt_y = layout.safe.bottom - layout.margin - (prompt_size * 0.6)

      # The rows' type size, and the height of a row.
      def text_size = [(row / look.line).floor, SMALLEST_TEXT].max
      def row = [layout.scaled(look.text) * look.line, room / columns.map { lines(it) }.max].min

      def wide? = layout.safe.width >= layout.safe.height * 1.2 && layout.safe.width >= layout.scaled(look.column) * 1.8

      # Each column's parts, as Placed, top to bottom.
      def placements
        widths = column_width
        left = layout.center_x - (((columns.size * widths) + ((columns.size - 1) * gap)) / 2.0)
        columns.each_with_index.flat_map { |parts, i| place(parts, left + (i * (widths + gap)), widths) }
      end

      private

      def columns
        chart = sheet.scores.empty? ? [] : [:chart]
        wide? ? [[sheet.bests], chart + [sheet.totals]] : [chart + [sheet.bests, sheet.totals]]
      end

      def gap = layout.scaled(look.gap)

      def column_width
        room = layout.safe.width - (layout.margin * 2) - ((columns.size - 1) * gap)
        [room / columns.size, layout.scaled(look.column)].min
      end

      # The body starts under the heading, lowered by a third of the room
      # its tallest column leaves, so it sits a little above the middle.
      def body_top
        top = heading_y + (heading_size * 0.8)
        top + [(room - (columns.map { lines(it) }.max * row)) / 3.0, 0.0].max
      end

      def body_bottom = prompt_y - (prompt_size * 1.1)
      def room = body_bottom - heading_y - (heading_size * 0.8)

      # How many rows a column's parts take, a section's title and the
      # space after it included.
      def lines(parts) = parts.sum { it == :chart ? look.chart + 1.6 : it.rows.size + 1.6 }

      def place(parts, x, width)
        y = body_top
        parts.flat_map do |part|
          if part == :chart
            placed = [Placed.new(item: Words.last_rounds(sheet.scores.size), x:, y: y + (row * 0.5), width:, height: row),
                      Placed.new(item: :chart, x:, y: y + row, width:, height: row * look.chart)]
            y += row * (look.chart + 1.6)
            next placed
          end

          placed = [part.title, *part.rows].each_with_index.map do |item, i|
            Placed.new(item:, x:, y: y + (row * (i + 0.5)), width:, height: row)
          end
          y += row * (part.rows.size + 1.6)
          placed
        end
      end
    end
  end
end
