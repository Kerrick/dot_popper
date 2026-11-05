# frozen_string_literal: true

module DotPopper
  module Presentation
    # One line of the Records screen: what it counts, and how many.
    class RecordRow < Data.define(:label, :value); end

    # A titled group of RecordRows.
    class RecordSection < Data.define(:title, :rows); end

    # What the Records screen says, worked out from LifetimeStats and the
    # best score: the player's bests, their totals, the daily goal's
    # streaks (+streak+ is the current one, as it stands today), and the
    # last few scores for the chart. The bests, and +best+, are those of
    # screens of +size_class+, the screen's now, and +notes+ say how big
    # +field+, the screen, is, and what +sizing+ (DotSizing) does. With no round played yet, +empty+ is true
    # and there is nothing to list.
    class RecordsSheet < Data.define(:bests, :totals, :goal, :scores, :empty, :notes)
      def self.build(stats, best:, words:, streak: 0, size_class: SizeClass::MEDIUM, field: nil,
                     sizing: DotSizing::STANDARD)
        labels = words.labels
        mine = stats.bests_in(size_class)
        bests = RecordSection.new(title: words.bests_heading(sizing), rows: [
          RecordRow.new(label: labels[:best_score], value: best.to_s),
          RecordRow.new(label: labels[:longest_round], value: Words.count(mine.longest_round.round, "second")),
          RecordRow.new(label: labels[:longest_run], value: mine.longest_run.to_s),
          RecordRow.new(label: labels[:fastest_pop], value: words.seconds_or_none(mine.fastest_pop)),
          RecordRow.new(label: labels[:longest_wait], value: words.seconds_or_none(mine.longest_wait))
        ])
        totals = RecordSection.new(title: labels[:totals], rows: [
          RecordRow.new(label: labels[:rounds], value: stats.rounds.to_s),
          RecordRow.new(label: labels[:pops], value: stats.pops.to_s),
          RecordRow.new(label: labels[:slips], value: stats.slips.to_s),
          RecordRow.new(label: labels[:seconds], value: Words.duration(stats.seconds)),
          RecordRow.new(label: labels[:days], value: stats.days.to_s)
        ])
        goal = RecordSection.new(title: labels[:goal], rows: [
          RecordRow.new(label: labels[:streak], value: Words.count(streak, "day")),
          RecordRow.new(label: labels[:longest_streak], value: Words.count(stats.streak.longest, "day"))
        ])
        new(bests:, totals:, goal:, scores: stats.recent, empty: stats.rounds.zero?,
            notes: field ? words.screen_notes(field, sizing) : [])
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
    # chart and the sections, in centred columns no wider than +widest+,
    # the room the longest row needs as the shell measures it, so a label
    # sits near its number. A wide screen puts the bests and the daily
    # goal on the left and the chart and totals on the right, when the two
    # columns fit side by side; otherwise they stack. Rows shrink, never
    # below a readable size, to fit a short screen. Under the heading go
    # the sheet's notes, in +note_lines+ lines once the shell has wrapped
    # them to fit across.
    class RecordsLayout < Data.define(:layout, :sheet, :look, :note_lines, :widest)
      SMALLEST_TEXT = 11

      def initialize(layout:, sheet:, look:, note_lines: sheet.notes.size, widest: nil) = super

      def heading_size = layout.scaled(look.heading)
      def heading_y = layout.top + (heading_size * 0.6)

      # The notes' type size, and where the middle of their line +i+ goes.
      def note_size = [layout.scaled(look.text * 0.9), SMALLEST_TEXT].max
      def note_y(i) = heading_y + (heading_size * 0.75) + (note_size * 1.3 * (i + 0.5))
      def prompt_size = layout.scaled(Look::TYPE.prompt)
      def prompt_y = layout.safe.bottom - layout.margin - (prompt_size * 0.6)

      # The rows' type size, and the height of a row.
      def text_size = [(row / look.line).floor, SMALLEST_TEXT].max
      def row = [layout.scaled(look.text) * look.line, room / columns.map { lines(it) }.max].min

      def wide?
        layout.safe.width >= layout.safe.height * 1.2 &&
          layout.safe.width - (layout.margin * 2) >= (wanted * 2) + gap
      end

      # Each column's parts, as Placed, top to bottom.
      def placements
        widths = column_width
        left = layout.center_x - (((columns.size * widths) + ((columns.size - 1) * gap)) / 2.0)
        columns.each_with_index.flat_map { |parts, i| place(parts, left + (i * (widths + gap)), widths) }
      end

      private

      def columns
        chart = sheet.scores.empty? ? [] : [:chart]
        wide? ? [[sheet.bests, sheet.goal], chart + [sheet.totals]] : [chart + [sheet.bests, sheet.totals, sheet.goal]]
      end

      def gap = layout.scaled(look.gap)

      def column_width
        room = layout.safe.width - (layout.margin * 2) - ((columns.size - 1) * gap)
        [room / columns.size, wanted].min
      end

      # How wide a column would like to be: as its longest row needs, and
      # never past the look's widest.
      def wanted = [widest || Float::INFINITY, layout.scaled(look.column)].min

      # The body starts under the heading, lowered by a third of the room
      # its tallest column leaves, so it sits a little above the middle.
      def body_top
        top = heading_bottom
        top + [(room - (columns.map { lines(it) }.max * row)) / 3.0, 0.0].max
      end

      def body_bottom = prompt_y - (prompt_size * 1.1)
      def room = body_bottom - heading_bottom

      # Where the heading and its notes end.
      def heading_bottom
        notes = note_lines.positive? ? (note_size * 1.3 * note_lines) + (note_size * 0.5) : 0.0
        heading_y + (heading_size * 0.8) + notes
      end

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
