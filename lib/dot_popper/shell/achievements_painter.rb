# frozen_string_literal: true

module DotPopper
  module Shell
    # The Achievements screen, a grid of icons a tap explains, and the
    # dialog over it: name, how it is earned, and for Pro the day or the
    # progress.
    class AchievementsPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        words = show.words
        Header.new(pen:).draw(show, layout, words.button(:achievements_title))
        pen.text(Presentation::AchievementWords.count(show.achievement_count), pen.fonts.semibold(16), layout.center_x, layout.heading_y + (layout.heading_size * 0.72), pen.palette.soft) if show.pro?
        window = show.achievements_layout.window
        pixels = pen.pixels
        G.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        show.achievement_cells.each { cell(show, it) }
        G.scissor = nil
        how_to_earn(show, layout) if words.input == Presentation::InputKind::GAMEPAD
      end

      def dialog(show, layout)
        plan = show.dialog_plan
        id = show.dialog
        shade(layout)
        card(plan.card)
        emblem(id, plan.card.center_x, plan.icon_y, plan.radius, show.achievement_earned?(id))
        name = Presentation::AchievementWords.name(id)
        pen.text(name, pen.fonts.bold(32), plan.card.center_x, plan.name_y, pen.palette.cream)
        status(show, id, plan) if show.dialog_status(id)
        font = pen.fonts.semibold(plan.line_size)
        plan.lines.each_with_index { |line, i| pen.text(line, font, plan.card.center_x, plan.lines_y + (font.height * (i + 0.5)), pen.palette.cream) }
        progress(show, id, plan) if plan.bar
        buttons(show, plan)
      end

      # An achievement's sign at +x+, +y+, +radius+ across: on gold where
      # +earned+, and in a dashed ring where not yet, as the grid shows it
      # and the offer of Pro shows the one tapped.
      def emblem(id, x, y, radius, earned, lit: 0.0)
        palette = pen.palette
        if earned
          pen.color(palette.fresh_body.mix(palette.fresh_light, 0.2))
          G.circle(:fill, x, y, radius, 64)
          pen.color(palette.cream)
          G.line_width = pen.pixels.line_width(1)
          G.circle(:line, x, y, radius, 64)
        else
          pen.color(palette.ink_bottom, 0.7)
          G.circle(:fill, x, y, radius, 64)
          pen.color(palette.soft, 0.45)
          G.line_width = pen.pixels.line_width(1.2)
          dashes(x, y, radius)
        end
        pen.color(palette.cream, 0.2 * lit)
        G.circle(:fill, x, y, radius, 64) if lit.positive?
        glyph = Presentation::AchievementWords.glyph(id)
        Glyphs.new(pen:).draw(glyph, x, y, radius * 1.15, color: earned ? palette.ink_bottom : palette.soft, weight: 2.0)
      end

      private

      def cell(show, cell)
        earned = show.achievement_earned?(cell.id)
        emblem(cell.id, cell.x, cell.y, cell.radius, earned, lit: show.hover.level([:achievement, cell.id]))
        name = Presentation::AchievementWords.name(cell.id)
        lines = Presentation::Words.wrap(name, cell.radius * 2.8) { pen.fonts.semibold(15).width(it) }
        font = pen.fonts.semibold(15)
        lines.each_with_index { |line, i| pen.text(line, font, cell.x, cell.name_y + (font.height * i), earned ? pen.palette.cream : pen.palette.soft) }
      end

      def dashes(x, y, radius)
        segments = 36
        segments.times do |i|
          next if i.odd?

          a = i * 2 * Math::PI / segments
          b = (i + 1) * 2 * Math::PI / segments
          G.line(x + (radius * Math.cos(a)), y + (radius * Math.sin(a)), x + (radius * Math.cos(b)), y + (radius * Math.sin(b)))
        end
      end

      def status(show, id, plan)
        text = show.dialog_status(id)
        font = pen.fonts.semibold(17)
        if show.achievement_earned?(id)
          x = plan.card.center_x - (font.width(text) / 2.0) - 14
          Glyphs.new(pen:).draw(:check, x, plan.status_y, 15, color: pen.palette.gain)
          pen.text(text, font, plan.card.center_x + 8, plan.status_y, pen.palette.gain)
        else
          pen.text(text, font, plan.card.center_x, plan.status_y, pen.palette.soft)
        end
      end

      def progress(show, id, plan)
        have, goal = show.achievement_progress(id)
        rect = plan.bar
        small = pen.fonts.semibold(15)
        label = show.words.button(:your_record)
        pen.text(label, small, rect.x + (small.width(label) / 2.0), rect.y - 16, pen.palette.soft)
        count = "#{have} of #{goal}"
        pen.text(count, small, rect.right - (small.width(count) / 2.0), rect.y - 16, pen.palette.cream)
        pen.color(pen.palette.ink_bottom, 0.8)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, rect.height / 2.0, rect.height / 2.0, 12)
        share = [have.to_f / goal, 1.0].min
        pen.color(pen.palette.fresh_body)
        G.rectangle(:fill, rect.x, rect.y, [rect.width * share, rect.height].max, rect.height, rect.height / 2.0, rect.height / 2.0, 12) if share.positive?
      end

      def buttons(show, plan)
        plan.buttons.each do |name, rect|
          case name
          when :achievement_pro
            PrimaryButton.new(pen:).draw(rect, show.words.button(:achievement_pro), hover: show.hover.level(name), ratio: PillButton::LABEL)
          when :achievement_close
            PillButton.new(pen:).draw(rect, show.words.button(:achievement_close), hover: show.hover.level(name))
          when :achievement_prev
            step(show, name, rect, :chevron_left, "LB")
          when :achievement_next
            step(show, name, rect, :chevron_right, "RB")
          end
        end
      end

      def step(show, name, rect, glyph, word)
        PillButton.new(pen:).draw(rect, word, hover: show.hover.level(name),
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(glyph, x, y, size * 0.34) })
      end

      def how_to_earn(show, layout)
        rect = layout.clear_stats_button
        PillButton.new(pen:).draw(rect, show.words.button(:how_to_earn))
      end

      def shade(layout)
        pen.color(pen.palette.ink_edge, 0.85)
        G.rectangle(:fill, -1, -1, layout.width + 2, layout.height + 2)
      end

      def card(rect)
        corner = 24.0
        pen.color(pen.palette.ink_top)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        pen.color(pen.palette.soft, 0.3)
        G.line_width = pen.pixels.line_width(1)
        G.rectangle(:line, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end
    end
  end
end
