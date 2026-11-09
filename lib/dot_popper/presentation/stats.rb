# frozen_string_literal: true

module DotPopper
  module Presentation
    # One line of the Stats screen: what it counts, and how many. A
    # achievement's line (AchievementWords) also has a +mark+ before its label, :earned,
    # :open, or :locked, for one the paid version has not shown yet.
    class StatsRow < Data.define(:label, :value, :mark)
      def initialize(label:, value:, mark: nil) = super
    end

    # A titled group of RecordRows.
    class StatsSection < Data.define(:title, :rows); end

    # What the Stats screen says, worked out from Stats and the
    # best score: the player's bests, their totals, the daily goal's
    # streaks (+streak+ is the current one, as it stands today), and the
    # last few scores for the chart. The bests, and +best+, are those of
    # screens of +size_class+, the screen's now, and +notes+ say how big
    # +field+, the screen, is, and what +sizing+ (DotSizing) does. With no game played yet, +empty+ is true
    # and there is nothing to list. +mine+ says, for each of the last
    # +scores+, whether it was played in +size_class+, and so counts
    # toward the bests shown; the chart dims the others, and +chart_note+
    # says so whenever there are any. +achievements+ lists the achievements, or is nil
    # when the sheet is built with no Achievements to list.
    class StatsSheet < Data.define(:bests, :totals, :goal, :scores, :empty, :notes, :mine, :chart_note, :achievements)
      # The achievements as a section, each with its mark filled if earned,
      # which a free player is shown too (what was earned while free is
      # kept, Achievements). With the paid version the rest are open, and
      # the heading counts; without it the rest are locked, under a heading
      # that says where they come from.
      def self.achievements_section(achievements, paid:)
        return unless achievements

        rows = Achievement::IDS.map do |id|
          mark = if achievements.earned?(id) then :earned
                 else paid ? :open : :locked
                 end
          StatsRow.new(label: AchievementWords.name(id), value: AchievementWords.mark(id), mark:)
        end
        heading = paid ? AchievementWords.heading(achievements.count) : AchievementWords::LOCKED_HEADING
        StatsSection.new(title: heading, rows:)
      end

      def self.build(stats, best:, words:, streak: 0, size_class: SizeClass::MEDIUM, field: nil,
                     sizing: DotSizing::STANDARD, achievements: nil, paid: false)
        labels = words.labels
        mine = stats.bests_in(size_class)
        bests = StatsSection.new(title: words.bests_heading(sizing), rows: [
          StatsRow.new(label: labels[:best_score], value: best.to_s),
          StatsRow.new(label: labels[:longest_game], value: Words.count(mine.longest_game.round, "second")),
          StatsRow.new(label: labels[:most_dots_in_a_row], value: mine.most_dots_in_a_row.to_s),
          StatsRow.new(label: labels[:shortest_time_to_pop], value: words.seconds_or_none(mine.shortest_time_to_pop)),
          StatsRow.new(label: labels[:longest_time_to_pop], value: words.seconds_or_none(mine.longest_time_to_pop))
        ])
        totals = StatsSection.new(title: labels[:totals], rows: [
          StatsRow.new(label: labels[:games], value: stats.games.to_s),
          StatsRow.new(label: labels[:pops], value: stats.pops.to_s),
          StatsRow.new(label: labels[:mistakes], value: stats.mistakes.to_s),
          StatsRow.new(label: labels[:seconds], value: Words.duration(stats.seconds)),
          StatsRow.new(label: labels[:days], value: stats.days.to_s)
        ])
        goal = StatsSection.new(title: labels[:goal], rows: [
          StatsRow.new(label: labels[:streak], value: Words.count(streak, "day")),
          StatsRow.new(label: labels[:longest_streak], value: Words.count(stats.streak.longest, "day"))
        ])
        mine = stats.recent_classes.map { it == size_class }
        new(bests:, totals:, goal:, scores: stats.recent, empty: stats.games.zero?,
            notes: field ? words.screen_notes(field, sizing) : [], mine:,
            chart_note: (words.chart_note(sizing) unless mine.all?), achievements: achievements_section(achievements, paid:))
      end
    end

    # One bar of the score chart, on whole device pixels; +best+ marks the
    # highest score shown of those that count toward the bests shown, and
    # +dim+ a bar that does not.
    class ScoreBar < Data.define(:x, :y, :width, :height, :score, :best, :dim)
      def initialize(x:, y:, width:, height:, score:, best:, dim: false) = super
    end

    # The last scores as bars, oldest on the left, in +slots+ places of
    # equal width so the chart fills up as games are played. Bars stand
    # on the bottom of their rect, as tall as their score against the
    # highest; a game of 0 still shows a stub one device pixel high.
    # +mine+ says which scores count toward the bests shown (by default,
    # all); the others are dim, and never the best, though they keep
    # their true height, so every bar is drawn to one scale.
    class ScoreBars < Data.define(:scores, :slots, :mine)
      def initialize(scores:, slots: Stats::RECENT, mine: [true] * scores.size) = super

      def bars(rect, pixels)
        highest = scores.max || 0
        counted = scores.each_index.select { mine[it] }
        best = counted.max_by { [scores[it], it] }
        slot = rect.width / slots
        gap = pixels.whole([slot * 0.22, 2 / pixels.scale].max)
        bottom = pixels.snap(rect.bottom)
        scores.each_with_index.map do |score, i|
          left = pixels.snap(rect.x + (i * slot))
          tall = highest.positive? ? pixels.whole(rect.height * score / highest) : pixels.whole(0)
          ScoreBar.new(x: left, y: bottom - tall, width: pixels.snap(rect.x + ((i + 1) * slot)) - left - gap,
                       height: tall, score:, best: i == best, dim: !mine[i])
        end
      end
    end

    # The line under the score chart that says what its dim bars are.
    class ChartNote < Data.define(:text); end

    # Where a part of the Stats screen goes: +item+ is a section's title
    # or the chart's (a String), a RecordRow, :chart, or a ChartNote. A text line is
    # centred on +y+; the chart's box starts at +y+ and is +height+ tall.
    class Placed < Data.define(:item, :x, :y, :width, :height)
      def right = x + width
    end

    # Sizes for the Stats screen, in graphics units at a scale of 1:
    # the heading's and the rows' type, a row's height as a multiple of
    # its type, the chart's height in rows, the gap between two columns,
    # a column's widest, and how dark the title's dots are behind it.
    class StatsLook < Data.define(:heading, :text, :line, :chart, :gap, :column, :veil); end

    # The Stats screen laid out in the safe area: the heading at the
    # top, the prompt to go back at the bottom, over the row of "Clear my
    # records…" (Layout#clear_records_button), and between them the
    # chart and the sections, in centred columns no wider than +widest+,
    # the room the longest row needs as the shell measures it, so a label
    # sits near its number. A wide screen puts the bests and the daily
    # goal on the left and the chart and totals on the right, when the two
    # columns fit side by side; otherwise they stack. Rows shrink, never
    # below a readable size, to fit a short screen. Under the heading go
    # the sheet's notes, in +note_lines+ lines once the shell has wrapped
    # them to fit across.
    class StatsLayout < Data.define(:layout, :sheet, :look, :note_lines, :widest, :looks, :offer)
      SMALLEST_TEXT = 11

      def initialize(layout:, sheet:, look:, note_lines: sheet.notes.size, widest: nil, looks: false, offer: false) = super

      def heading_size = layout.scaled(look.heading)
      def heading_y = layout.top + (heading_size * 0.6)

      # The notes' type size, and where the middle of their line +i+ goes.
      def note_size = [layout.scaled(look.text * 0.9), SMALLEST_TEXT].max
      def note_y(i) = heading_y + (heading_size * 0.75) + (note_size * 1.3 * (i + 0.5))
      def prompt_size = layout.scaled(Look::TYPE.prompt)
      # The prompt to go back sits over the row of "Clear my records…".
      def prompt_y = layout.stats_floor(looks:, offer:) - layout.margin - (prompt_size * 0.6)

      # The rows' type size, and the height of a row.
      def text_size = [(row / look.line).floor, SMALLEST_TEXT].max
      def row = [layout.scaled(look.text) * look.line, room / columns.map { lines(it) }.max].min

      def wide? = layout.safe.width >= layout.safe.height * 1.2 && fits?(2)

      # Whether +count+ columns, of the width they want, fit side by side.
      def fits?(count) = layout.safe.width - (layout.margin * 2) >= (wanted * count) + (gap * (count - 1))

      # Each column's parts, as Placed, top to bottom.
      def placements
        widths = column_width
        left = layout.center_x - (((columns.size * widths) + ((columns.size - 1) * gap)) / 2.0)
        columns.each_with_index.flat_map { |parts, i| place(parts, left + (i * (widths + gap)), widths) }
      end

      private

      # The achievements take a column of their own where three fit, or else go
      # under whichever of two is shorter.
      def columns
        chart = sheet.scores.empty? ? [] : [:chart]
        return [chart + [sheet.bests, sheet.totals, sheet.goal, *sheet.achievements]] unless wide?

        two = [[sheet.bests, sheet.goal], chart + [sheet.totals]]
        return two unless sheet.achievements
        return two + [[sheet.achievements]] if fits?(3)

        shorter = two.each_index.min_by { lines(two[it]) }
        two.each_with_index.map { |parts, i| i == shorter ? parts + [sheet.achievements] : parts }
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
      def lines(parts) = parts.sum { it == :chart ? chart_lines : it.rows.size + 1.6 }

      # The chart's rows: its title, its bars, and the note under it, if
      # any, which may take two lines of its smaller type.
      def chart_lines = look.chart + 1.6 + (sheet.chart_note ? 1.4 : 0.0)

      def place(parts, x, width)
        y = body_top
        parts.flat_map do |part|
          if part == :chart
            placed = [Placed.new(item: Words.last_games(sheet.scores.size), x:, y: y + (row * 0.5), width:, height: row),
                      Placed.new(item: :chart, x:, y: y + row, width:, height: row * look.chart)]
            if sheet.chart_note
              note = ChartNote.new(text: sheet.chart_note)
              placed << Placed.new(item: note, x:, y: y + (row * (look.chart + 1.75)), width:, height: row * 1.2)
            end
            y += row * chart_lines
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
