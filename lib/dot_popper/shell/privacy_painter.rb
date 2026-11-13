# frozen_string_literal: true

module DotPopper
  module Shell
    # The Privacy screen: what stays and what is kept online, a link to
    # the policy, and a held button that deletes the online data.
    class PrivacyPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        plan = show.privacy_plan
        words = show.words
        Header.new(pen:).draw(show, layout, words.button(:privacy_heading))
        lines(plan)
        policy(show, plan)
        delete(show, plan) if plan.delete
        note(show, plan, layout) unless plan.note_lines.empty?
      end

      private

      def lines(plan)
        font = pen.fonts.semibold(plan.line_size)
        plan.lines.each do |glyph, rows, top|
          Glyphs.new(pen:).draw(glyph, plan.left + 13, top + (font.height / 2.0), 24, color: pen.palette.bright_body)
          rows.each_with_index do |row, i|
            pen.text(row, font, plan.left + 42 + (font.width(row) / 2.0), top + (font.height * (i + 0.5)) + (i * plan.line_size * 0.15), pen.palette.cream)
          end
        end
      end

      def policy(show, plan)
        rect = plan.policy
        PillButton.new(pen:).draw(rect, nil, hover: show.hover.level(:policy),
                                  icon: lambda do |x, y, size|
                                    font = pen.fonts.semibold((size * 0.33).round)
                                    text = show.words.button(:privacy_policy)
                                    total = font.width(text) + 40
                                    left = rect.center_x - (total / 2.0)
                                    pen.text(text, font, left + (font.width(text) / 2.0), rect.center_y, pen.palette.cream)
                                    Glyphs.new(pen:).draw(:external, left + total - 10, rect.center_y, size * 0.34, color: pen.palette.cream)
                                    [x, y]
                                  end)
      end

      def delete(show, plan)
        rect = plan.delete
        hold = show.group_panel.hold
        amount = hold.progress(show.now)
        PillButton.new(pen:).draw(rect, nil, hover: show.hover.level(:privacy_delete), edge: pen.palette.urgent,
                                  icon: lambda do |_x, y, size|
                                    fill(rect, amount) if hold.held?
                                    font = pen.fonts.semibold((size * 0.33).round)
                                    text = show.words.button(:privacy_delete)
                                    total = font.width(text) + 40
                                    left = rect.center_x - (total / 2.0)
                                    Glyphs.new(pen:).draw(:trash, left + 10, y, size * 0.34, color: pen.palette.urgent)
                                    pen.text(text, font, left + 40 + (font.width(text) / 2.0), y, pen.palette.urgent)
                                  end)
      end

      def fill(rect, amount)
        outline = Presentation::PillFill.new(rect:, amount:).outline
        return if outline.size < 6

        pen.color(pen.palette.alarm, 0.45)
        G.polygon(:fill, *outline)
      end

      def note(show, plan, layout)
        font = pen.fonts.semibold(15)
        y = plan.note_y + 6
        pen.text(show.words.button(:privacy_hold), font, layout.center_x, y, pen.palette.soft) unless show.group_panel.hold.held?
        lines = Presentation::Words.wrap(show.words.button(:privacy_hold), plan.delete.width) { font.width(it) }
        lines.each_with_index { |line, i| pen.text(line, font, layout.center_x, y + (i * font.height), pen.palette.soft) } if lines.size > 1
      end
    end
  end
end
