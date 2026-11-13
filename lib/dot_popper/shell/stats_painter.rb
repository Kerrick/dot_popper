# frozen_string_literal: true

module DotPopper
  module Shell
    # The Stats screen, in cards in a list that scrolls: Highest score and
    # the chart of the last games, the records, the daily goal, and the
    # totals. Back is in one corner; "Clear my stats…" (or, once they are
    # cleared, Undo) is in the other, and while it is held the prompt says
    # what will go.
    class StatsPainter < Data.define(:pen)
      G = ::Lota::Graphics
      DIM = 0.3 # how much of a bar shows when its game counts elsewhere

      def draw(show, layout)
        sheet = show.stats or return
        words = show.words
        plan = show.stats_layout
        Header.new(pen:).draw(show, layout, words.stats)
        note = show.stats_note
        pen.text(note, pen.fonts.semibold(15), layout.center_x, plan.note_y, pen.palette.soft) if note
        prompt(show, layout)
        corner(show, layout)
        return nothing_yet(words, layout) if sheet.empty

        cards(show, sheet, plan)
      end

      private

      def cards(show, sheet, plan)
        window = plan.window
        placed, height = plan.cards
        scroll = show.list_fit(height, window.height)
        pixels = pen.pixels
        G.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        placed.each do |card|
          rect = card.rect.with(y: window.y + card.rect.y - scroll.offset)
          Card.new(pen:).draw(rect)
          send(card.kind, show, sheet, rect)
        end
        G.scissor = nil
      end

      def chart(show, sheet, rect)
        palette = pen.palette
        pad = 14.0
        label = pen.fonts.semibold(14)
        left(sheet.records.rows.first.label, label, rect.x + pad, rect.y + 22, palette.soft)
        big = pen.fonts.bold(rect.height > 200 ? 56 : 44)
        Lettering.new(pen:).candy(sheet.records.rows.first.value, big, rect.x + pad + (big.width(sheet.records.rows.first.value) / 2.0), rect.y + 22 + (big.height * 0.72), 1.0, face: palette.bright_body, side: palette.bright_deep)
        caption = Presentation::Words.last_games(sheet.scores.size)
        right(caption, label, rect.right - pad, rect.y + 22 + (big.height * 1.05), palette.soft)
        top = rect.y + 22 + (big.height * 1.35)
        note = sheet.chart_note ? 22.0 : 0.0
        bars(sheet, Presentation::Rect.new(x: rect.x + pad, y: top, width: rect.width - (2 * pad), height: rect.bottom - top - 12 - note))
        left(sheet.chart_note, pen.fonts.semibold(13), rect.x + pad, rect.bottom - 16, palette.soft) if sheet.chart_note
      end

      def bars(sheet, box)
        palette = pen.palette
        Presentation::ScoreBars.new(scores: sheet.scores, mine: sheet.mine).bars(box, pen.pixels).each do |bar|
          pen.color(bar.score_record ? palette.bright_light : palette.bright_body.mix(palette.bright_deep, 0.45), bar.dim ? DIM : 1.0)
          corner = [bar.width / 3.0, 2.0].min
          G.rectangle(:fill, bar.x, bar.y, bar.width, bar.height, corner, corner, 8)
        end
      end

      def records(_show, sheet, rect) = rows("Records", sheet.records.rows.drop(1), rect, Presentation::StatsLayout::RECORD_ROW, 18)
      def totals(_show, sheet, rect) = rows(sheet.totals.heading, sheet.totals.rows, rect, Presentation::StatsLayout::TOTAL_ROW, 16)

      def rows(heading, rows, rect, height, size)
        palette = pen.palette
        pad = 16.0
        left(heading, pen.fonts.semibold(14), rect.x + pad, rect.y + 16, palette.soft)
        # One size for every row of the card: the largest at which each
        # row's label fits beside its value.
        # a label that still does not fit breaks onto two lines.
        room = rect.width - (2 * pad) - 14
        least = (size * 0.8).round
        size -= 1 while size > least && rows.any? { pen.fonts.semibold(size).width(it.label) + pen.fonts.bold(size).width(it.value) > room }
        font = pen.fonts.semibold(size)
        rows.each_with_index do |row, i|
          y = rect.y + 30 + (i * height) + (height / 2.0)
          lines = Presentation::Words.wrap(row.label, room - pen.fonts.bold(size).width(row.value)) { font.width(it) }
          lines = [row.label] if lines.size > 2
          step = [font.height * 0.95, height / 2.0].min
          lines.each_with_index { |line, n| left(line, font, rect.x + pad, y + ((n - ((lines.size - 1) / 2.0)) * step), palette.cream) }
          right(row.value, pen.fonts.bold(size), rect.right - pad, y, palette.cream)
          next if i.zero?

          pen.color(palette.soft, 0.18)
          G.rectangle(:fill, rect.x + pad, pen.pixels.snap(y - (height / 2.0)), rect.width - (2 * pad), pen.pixels.line_width(1))
        end
      end

      def goal(show, sheet, rect)
        palette = pen.palette
        left(sheet.goal.heading, pen.fonts.semibold(14), rect.x + 14, rect.y + 16, palette.soft)
        rows = sheet.goal.rows
        [rows[0], rows[1]].each_with_index do |row, i|
          x = rect.x + (rect.width * (i.zero? ? 0.27 : 0.73))
          pen.text(row.value[/\d+/].to_s, pen.fonts.bold(26), x, rect.y + 40, palette.cream)
          pen.text(row.label, fit_label(row.label, 14, rect.width * 0.46), x, rect.y + 64, palette.soft)
        end
      end

      def fit_label(text, size, room)
        size -= 1 while size > 11 && pen.fonts.semibold(size).width(text) > room
        pen.fonts.semibold(size)
      end

      # While "Clear my stats…" is held, what holding it will clear; and
      # for a moment after a press let go too soon, that it must be held.
      def prompt(show, layout)
        words = show.words
        clearing = show.clearing
        hint = pen.style::STATS_CLEAR.hint
        ago = clearing.let_go_ago(show.now)
        if clearing.held? then say(words.keep_holding(show.holding_button), layout, 1.0)
        elsif ago && ago < hint then say(words.hold_to_clear, layout, ((hint - ago) / 0.5).clamp(0.0, 1.0))
        end
      end

      def say(text, layout, alpha)
        font = pen.fonts.semibold(15)
        y = layout.short? ? layout.safe.bottom - 14 : layout.back_button.y - 14
        Presentation::Words.balance(text, layout.safe.width - 32) { font.width(it) }.reverse.each_with_index do |line, i|
          pen.text(line, font, layout.center_x, y - (i * font.height), pen.palette.cream, alpha)
        end
      end

      def corner(show, layout)
        if (offer = show.undo_offer) then undo(show, offer, layout)
        elsif show.clear_offered? then clear(show, layout)
        end
      end

      def clear(show, layout)
        rect = layout.clear_stats_button
        held = show.clearing.held?
        hover = show.hover.level(:clear)
        PillButton.new(pen:).draw(rect, show.words.clear, hover:)
        return unless held

        outline = Presentation::PillFill.new(rect:, amount: show.clearing.progress(show.now)).outline
        if outline.size >= 6
          pen.color(pen.palette.alarm, 0.55)
          G.polygon(:fill, *outline)
        end
        PillButton.new(pen:).label(rect, show.words.clear)
      end

      def undo(show, offer, layout)
        rect = layout.undo_button
        PillButton.new(pen:).draw(rect, show.words.undo, hover: show.hover.level(:undo))
        font = pen.fonts.semibold(15)
        text = show.words.cleared
        pen.text(text, font, rect.x - 12 - (font.width(text) / 2.0), rect.center_y, pen.palette.soft)
        amount = offer.left(show.now)
        return unless amount.positive?

        pen.color(pen.palette.soft, 0.5)
        G.rectangle(:fill, rect.x + (rect.height / 2.0), rect.bottom + 4, [(rect.width - rect.height) * amount, 1.0].max, pen.pixels.line_width(3))
      end

      def nothing_yet(words, layout)
        pen.text(words.no_games, pen.fonts.semibold(18), layout.center_x, layout.center_y, pen.palette.soft)
      end

      def left(text, font, x, y, color) = pen.text(text, font, x + (font.width(text) / 2.0), y, color)
      def right(text, font, x, y, color) = pen.text(text, font, x - (font.width(text) / 2.0), y, color)
    end
  end
end
