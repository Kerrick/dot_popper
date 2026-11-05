# frozen_string_literal: true

module DotPopper
  module Shell
    # The Records screen, over the title's dimmed dots: the heading, the
    # notes on the screen's size under it, the chart of the last scores,
    # the bests and totals as rows with their labels on the left and
    # their numbers lined up on the right, a faint dotted leader between,
    # the prompt to go back, and under it, in the corner, "Clear my
    # records…" or, once they are cleared, Undo. While "Clear my records…"
    # is held, the prompt says what will go, and a bar under it fills.
    # Presentation::RecordsLayout decides where each goes; this only draws,
    # on whole device pixels.
    class RecordsPainter < Data.define(:pen)
      G = ::Lota::Graphics
      DIM = 0.3 # how much of a bar shows when its round counts elsewhere

      def draw(show, layout)
        sheet = show.records or return
        words = show.words
        palette = pen.palette
        plan = Presentation::RecordsLayout.new(layout:, sheet:, look: pen.look::RECORDS,
                                               widest: widest(sheet, layout.scaled(pen.look::RECORDS.text)))
        notes = note_lines(sheet, plan, layout)
        plan = plan.with(note_lines: notes.size)
        pen.text(words.records, pen.fonts.bold(plan.heading_size), layout.center_x, plan.heading_y, palette.cream)
        font = pen.fonts.semibold(plan.note_size)
        notes.each_with_index { |line, i| pen.text(line, font, layout.center_x, plan.note_y(i), palette.soft) }
        prompt(show, plan, layout)
        corner(show, layout)
        return nothing_yet(words, layout, plan) if sheet.empty

        size = fit(plan)
        plan.placements.each { place(it, sheet, size) }
      end

      private

      # The room a column needs at type +size+: its longest row, a label
      # and its number with room for a short leader between, or its
      # longest title.
      def widest(sheet, size)
        label = pen.fonts.semibold(size)
        value = pen.fonts.bold(size)
        sections = [sheet.bests, sheet.totals, sheet.goal]
        rows = sections.flat_map(&:rows).map { label.width(it.label) + value.width(it.value) + (size * 2) }
        titles = sections.map(&:title) + [Presentation::Words.last_rounds(sheet.scores.size)]
        (rows + titles.map { value.width(it) }).max
      end

      # The sheet's notes, each broken into even lines that fit across.
      def note_lines(sheet, plan, layout)
        font = pen.fonts.semibold(plan.note_size)
        room = layout.safe.width - (layout.margin * 2)
        sheet.notes.flat_map { |note| Presentation::Words.balance(note, room) { font.width(it) } }
      end

      # The prompt to go back, or while "Clear my records…" is held, what
      # holding it will clear; and for a moment after a press let go too
      # soon, that it must be held.
      def prompt(show, plan, layout)
        words = show.words
        clearing = show.clearing
        hint = pen.look::RECORDS_CLEAR.hint
        ago = clearing.let_go_ago(show.now)
        if clearing.held? then say(words.keep_holding(show.holding_button), plan, layout, 1.0)
        elsif ago && ago < hint then say(words.hold_to_clear, plan, layout, ((hint - ago) / 0.5).clamp(0.0, 1.0))
        else
          pen.text(words.go_back, pen.fonts.bold(plan.prompt_size), layout.center_x, plan.prompt_y, pen.palette.cream,
                   show.marquee.prompt(show.now))
        end
      end

      # +text+ where the prompt goes, in a line or two that fit across.
      def say(text, plan, layout, alpha)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(plan.prompt_size * 0.85))
        lines = Presentation::Words.balance(text, layout.safe.width - (layout.margin * 2)) { font.width(it) }
        lines.each_with_index do |line, i|
          y = plan.prompt_y + ((i - ((lines.size - 1) / 2.0)) * font.height * 1.1)
          pen.text(line, font, layout.center_x, y, pen.palette.cream, alpha)
        end
      end

      # The bottom right corner: Undo while it is offered, or else "Clear
      # my records…" while there are records to clear.
      def corner(show, layout)
        if (offer = show.undo_offer) then undo(show, offer, layout)
        elsif show.clear_offered? then clear(show, layout)
        end
      end

      # "Clear my records…", quiet in soft type. While it's held, the button
      # itself fills from the left in the alarm's pink, so how far along
      # the hold is can't be missed, and its words are drawn again on top.
      def clear(show, layout)
        rect = layout.clear_records_button
        held = show.clearing.held?
        PillButton.new(pen:).draw(rect, show.words.clear, alpha: held ? 1.0 : 0.8, color: pen.palette.soft)
        return unless held

        fill(rect, show.clearing.progress(show.now))
        PillButton.new(pen:).label(rect, show.words.clear, color: pen.palette.cream)
      end

      # The pill's left +amount+, filled, its ends rounded as the pill's are.
      def fill(rect, amount)
        return if amount <= 0.0

        pixels = pen.pixels
        width = pixels.snap(rect.width * amount.clamp(0.0, 1.0))
        corner = [rect.height, width].min / 2.0
        pen.color(pen.palette.alarm, 0.55)
        G.rectangle(:fill, pixels.snap(rect.x), pixels.snap(rect.y), width, pixels.snap(rect.height), corner, corner, 48)
      end

      # "Records cleared." beside Undo, and under Undo, a faint bar that
      # empties as the time to undo runs out.
      def undo(show, offer, layout)
        rect = layout.undo_button
        PillButton.new(pen:).draw(rect, show.words.undo)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(rect.height * 0.4))
        text = show.words.cleared
        pen.text(text, font, rect.x - layout.margin - (font.width(text) / 2.0), rect.center_y, pen.palette.soft)
        bar(rect, offer.left(show.now), pen.palette.soft, 0.5)
      end

      # A bar under +rect+, +amount+ of its width from the left.
      def bar(rect, amount, color, alpha)
        return if amount <= 0.0

        pixels = pen.pixels
        x = pixels.snap(rect.x + (rect.height / 2.0))
        width = pixels.snap((rect.width - rect.height) * amount)
        pen.color(color, alpha)
        G.rectangle(:fill, x, pixels.snap(rect.bottom + (rect.height * 0.12)), [width, pixels.line_width(1)].max,
                    pixels.line_width(3))
      end

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
          label = pen.fonts.semibold(size)
          value = pen.fonts.bold(size)
          left(row.label, label, placed.x, placed.y, palette.soft)
          right(row.value, value, placed.right, placed.y, palette.cream)
          leader(placed.x + label.width(row.label), placed.right - value.width(row.value), placed.y, size)
        in :chart then chart(sheet, placed, size)
        in Presentation::ChartNote => note then chart_note(note.text, placed, size)
        end
      end

      # A faint dotted line from a label to its number, so the eye keeps
      # its row across the gap between them.
      def leader(from, to, y, size)
        pixels = pen.pixels
        step = size * 0.5
        from += size * 0.6
        to -= size * 0.6
        return if to <= from

        pen.color(pen.palette.soft, 0.4)
        dot = pixels.line_width(1.5)
        line = pixels.snap(y + (size * 0.28))
        (from..to).step(step).each { G.rectangle(:fill, pixels.snap(it), line, dot, dot) }
      end

      def left(text, font, x, y, color) = pen.text(text, font, x + (font.width(text) / 2.0), y, color)
      def right(text, font, x, y, color) = pen.text(text, font, x - (font.width(text) / 2.0), y, color)

      # The last scores as bars on a faint baseline, in a fresh dot's
      # deeper orange, the best of them in its light cream and labelled
      # with its score: lighter, so it stands out by more than its hue. A
      # bar from a round that does not count toward the bests shown is
      # drawn faint, and never labelled. The chart's title, above it, is
      # placed as a section's is.
      def chart(sheet, placed, size)
        palette = pen.palette
        pixels = pen.pixels
        label = pen.fonts.bold(size)
        box = Presentation::Rect.new(x: placed.x, y: placed.y + label.height, width: placed.width,
                                     height: placed.height - label.height)
        bars = Presentation::ScoreBars.new(scores: sheet.scores, mine: sheet.mine).bars(box, pixels)
        bars.each do |bar|
          pen.color(bar.best ? palette.fresh_light : palette.fresh_deep, bar.dim ? DIM : 1.0)
          corner = [bar.width / 2.0, 2 / pixels.scale].min
          G.rectangle(:fill, bar.x, bar.y, bar.width, bar.height, corner, corner, 8)
        end
        baseline(box)
        best = bars.find(&:best)
        pen.text(best.score.to_s, label, best.x + (best.width / 2.0), best.y - (label.height * 0.6), palette.cream) if best
      end

      # The note under the chart, in the notes' smaller, softer type,
      # broken into even lines that fit across it.
      def chart_note(text, placed, size)
        font = pen.fonts.semibold([(size * 0.8).floor, Presentation::RecordsLayout::SMALLEST_TEXT].max)
        lines = Presentation::Words.balance(text, placed.width) { font.width(it) }.first(2)
        top = placed.y - (font.height * (lines.size - 1) / 2.0)
        lines.each_with_index do |line, i|
          pen.text(line, font, placed.x + (placed.width / 2.0), top + (font.height * i), pen.palette.soft)
        end
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
