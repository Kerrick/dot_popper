# frozen_string_literal: true

module DotPopper
  module Presentation
    # One line of the Stats screen: what it counts, and how many. A
    # achievement's line (AchievementWords) also has a +mark+ before its label, :earned,
    # :open.
    class StatsRow < Data.define(:label, :value, :mark)
      def initialize(label:, value:, mark: nil) = super
    end

    # A headed group of RecordRows.
    class StatsSection < Data.define(:heading, :rows); end

    # What the Stats screen says, worked out from Stats and the
    # score record: the player's records, their totals, the daily goal's
    # streaks (+streak+ is the current one, as it stands today), and the
    # last few scores for the chart. The records, and +score_record+, are those of
    # screens of +size_class+, the screen's now, and +notes+ say how big
    # +field+, the screen, is, and what +sizing+ (DotSizing) does, named as
    # +preview+ (SizingPreview) names it in Settings. With no game played yet, +empty+ is true
    # and there is nothing to list. +mine+ says, for each of the last
    # +scores+, whether it was played in +size_class+, and so counts
    # toward the records shown; the chart dims the others, and +chart_note+
    # says so whenever there are any. +achievements+ lists the achievements, or is nil
    # when the sheet is built with no Achievements to list.
    class StatsSheet < Data.define(:records, :totals, :goal, :scores, :empty, :notes, :mine, :chart_note, :achievements)
      # The achievements as a section, each with its mark filled if earned
      # and a ring if not, the same for a Free player and a Pro one (what is
      # earned while Free is kept, Achievements). It takes no tap: a Free
      # player is offered Pro from an achievement's dialog
      # (Screens::AchievementDialog#get_pro).
      def self.achievements_section(achievements)
        return unless achievements

        rows = Achievement::IDS.map do |id|
          StatsRow.new(label: AchievementWords.name(id), value: AchievementWords.mark(id),
                       mark: achievements.earned?(id) ? :earned : :open)
        end
        StatsSection.new(heading: AchievementWords.heading(achievements.count), rows:)
      end

      def self.build(stats, score_record:, words:, streak: 0, size_class: SizeClass::MEDIUM, field: nil,
                     sizing: DotSizing::FIXED, preview: nil, achievements: nil)
        labels = words.labels
        mine = stats.records_in(size_class)
        records = StatsSection.new(heading: words.records_heading(sizing, preview), rows: [
          StatsRow.new(label: labels[:score_record], value: score_record.to_s),
          StatsRow.new(label: labels[:longest_game], value: Words.count(mine.longest_game.round, "second")),
          StatsRow.new(label: labels[:most_dots_in_a_row], value: mine.most_dots_in_a_row.to_s),
          StatsRow.new(label: labels[:shortest_time_to_pop], value: words.seconds_or_none(mine.shortest_time_to_pop)),
          StatsRow.new(label: labels[:longest_time_to_pop], value: words.seconds_or_none(mine.longest_time_to_pop))
        ])
        totals = StatsSection.new(heading: labels[:totals], rows: [
          StatsRow.new(label: labels[:games], value: stats.games.to_s),
          StatsRow.new(label: labels[:dots_popped], value: stats.dots_popped.to_s),
          StatsRow.new(label: labels[:mistakes], value: stats.mistakes.to_s),
          StatsRow.new(label: labels[:seconds], value: Words.duration(stats.seconds)),
          StatsRow.new(label: labels[:days], value: stats.days.to_s)
        ])
        goal = StatsSection.new(heading: labels[:goal], rows: [
          StatsRow.new(label: labels[:streak], value: Words.count(streak, "day")),
          StatsRow.new(label: labels[:longest_streak], value: Words.count(stats.streak.longest, "day"))
        ])
        mine = stats.recent_classes.map { it == size_class }
        new(records:, totals:, goal:, scores: stats.recent, empty: stats.games.zero?,
            notes: field ? [words.screen_here(field)] : [], mine:,
            chart_note: (words.chart_note unless mine.all?), achievements: achievements_section(achievements))
      end
    end

    # One bar of the score chart, on whole device pixels; +score_record+ marks the
    # highest score shown of those that count toward the records shown, and
    # +dim+ a bar that does not.
    class ScoreBar < Data.define(:x, :y, :width, :height, :score, :score_record, :dim)
      def initialize(x:, y:, width:, height:, score:, score_record:, dim: false) = super
    end

    # The last scores as bars, oldest on the left, in +slots+ places of
    # equal width so the chart fills up as games are played. Bars stand
    # on the bottom of their rect, as tall as their score against the
    # highest; a game of 0 still shows a stub one device pixel high.
    # +mine+ says which scores count toward the records shown (by default,
    # all); the others are dim, and never marked as the record, though they keep
    # their true height, so every bar is drawn to one scale.
    class ScoreBars < Data.define(:scores, :slots, :mine)
      def initialize(scores:, slots: Stats::RECENT, mine: [true] * scores.size) = super

      def bars(rect, pixels)
        highest = scores.max || 0
        counted = scores.each_index.select { mine[it] }
        score_record = counted.max_by { [scores[it], it] }
        slot = rect.width / slots
        gap = pixels.whole([slot * 0.22, 2 / pixels.scale].max)
        bottom = pixels.snap(rect.bottom)
        scores.each_with_index.map do |score, i|
          left = pixels.snap(rect.x + (i * slot))
          tall = highest.positive? ? pixels.whole(rect.height * score / highest) : pixels.whole(0)
          ScoreBar.new(x: left, y: bottom - tall, width: pixels.snap(rect.x + ((i + 1) * slot)) - left - gap,
                       height: tall, score:, score_record: i == score_record, dim: !mine[i])
        end
      end
    end

    # The line under the score chart that says what its dim bars are.
    class ChartNote < Data.define(:text); end

    # Where a part of the Stats screen goes: +item+ is a section's heading
    # or the chart's (a String), a RecordRow, :chart, or a ChartNote. A text line is
    # centered on +y+; the chart's box starts at +y+ and is +height+ tall.
    class Placed < Data.define(:item, :x, :y, :width, :height)
      def right = x + width
    end

    # A card of the Stats screen: +kind+ is :chart, :records, :goal or
    # :totals, and +rect+ is where it goes, by the list's top.
    class StatsCard < Data.define(:kind, :rect); end

    # Sizes for the Stats screen, in graphics units at a scale of 1.
    class StatsStyle < Data.define(:heading, :text, :line, :chart, :gap, :column, :veil); end

    # The Stats screen laid out in cards, in the list's window under the
    # heading and its note: one column on a phone, two on a wide window,
    # three on a short one, as tall as their rows need. It scrolls where
    # the cards are taller than the window.
    class StatsLayout < Data.define(:layout, :sheet, :style)
      SMALLEST_TEXT = 11
      RECORD_ROW = 33.0
      TOTAL_ROW = 28.0
      GAP = 12.0

      def self.measured(layout:, sheet:, style:, measure: nil) = new(layout:, sheet:, style:)

      def heading_size = layout.heading_size
      def heading_y = layout.heading_y
      def note_y = layout.short? ? layout.safe.y + layout.page_margin + layout.control_height + 12.0 : heading_y + (heading_size * 0.72)

      def window
        page = layout.page
        top = layout.short? ? note_y + 10.0 : [page.y, note_y + 18.0].max
        page.with(y: top, height: [page.bottom - top, 0.0].max)
      end

      def columns = layout.short? ? 3 : (layout.safe.width >= 900 ? 2 : 1)

      # Each card where it goes in the list, and the list's height.
      def cards
        column_cards, height = arranged
        [column_cards.flatten, height]
      end

      def content_height = arranged.last

      private

      def chart_height = columns == 1 ? 183.0 : (columns == 3 ? 180.0 : 277.0)
      def records_height = 28.0 + (RECORD_ROW * 4) + 8
      def goal_height = columns == 3 ? 96.0 : 84.0
      def totals_height = 28.0 + (TOTAL_ROW * 5) + 8

      def groups
        return [%i[chart records goal totals]] if columns == 1
        return [%i[chart goal], %i[records totals]] if columns == 2

        [%i[chart], %i[records], %i[goal totals]]
      end

      def height_of(kind) = { chart: chart_height, records: records_height, goal: goal_height, totals: totals_height }.fetch(kind)

      def arranged
        area = window
        width = [(area.width - ((columns - 1) * GAP)) / columns, columns == 2 ? 552.0 : Float::INFINITY].min
        total = (columns * width) + ((columns - 1) * GAP)
        left = area.center_x - (total / 2.0)
        column_cards = groups.each_with_index.map do |kinds, c|
          y = 0.0
          kinds.map do |kind|
            card = StatsCard.new(kind:, rect: Rect.new(x: left + (c * (width + GAP)), y:, width:, height: height_of(kind)))
            y += height_of(kind) + GAP
            card
          end
        end
        height = column_cards.map { |cards| cards.map { it.rect.bottom }.max.to_f }.max
        [column_cards, height]
      end
    end
  end
end
