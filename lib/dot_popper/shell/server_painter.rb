# frozen_string_literal: true

module DotPopper
  module Shell
    # Change Server, as Presentation::ServerScreen lays it out: the warning
    # and what to do, each after its sign, which server is in use, Paste
    # server address, Use setdef's server once another is chosen, and how
    # the last paste went.
    class ServerPainter < Data.define(:pen)
      def draw(show, layout)
        plan = show.server_plan
        words = show.words
        Header.new(pen:).draw(show, layout, words.button(:server_title))
        lines(plan)
        line(plan.now, plan, plan.now_y, pen.palette.soft)
        PillButton.new(pen:).draw(plan.paste, words.button(:server_paste), hover: show.hover.level(:server_paste))
        PillButton.new(pen:).draw(plan.reset, words.button(:server_reset), hover: show.hover.level(:server_reset)) if plan.reset
        line(plan.status, plan, plan.status_y, pen.palette.cream) if plan.status
      end

      private

      def lines(plan)
        font = pen.fonts.semibold(plan.line_size)
        plan.lines.each do |glyph, rows, top|
          Glyphs.new(pen:).draw(glyph, plan.left + 13, top + (font.height / 2.0), 24, color: pen.palette.fresh_body)
          rows.each_with_index do |row, i|
            pen.text(row, font, plan.left + 42 + (font.width(row) / 2.0), top + (font.height * (i + 0.5)) + (i * plan.line_size * 0.15), pen.palette.cream)
          end
        end
      end

      # One centred line, smaller until it fits across, as a long address may need.
      def line(text, plan, y, color)
        size = 17
        size -= 1 while size > 10 && pen.fonts.semibold(size).width(text) > plan.width
        pen.text(text, pen.fonts.semibold(size), plan.left + (plan.width / 2.0), y, color)
      end
    end
  end
end
