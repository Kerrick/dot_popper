# frozen_string_literal: true

module DotPopper
  module Shell
    # A trophy drawn in shapes, as the other icons are: a cup, its handles
    # and its foot, in a square +size+ across around +x+, +y+.
    class TrophyIcon < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(x, y, size, alpha = 1.0, color: pen.palette.fresh_light)
        s = size * 0.5
        pen.color(color, alpha)
        G.line_width = pen.pixels.line_width(2)
        G.circle(:line, x - (s * 0.46), y - (s * 0.28), s * 0.2, 16)
        G.circle(:line, x + (s * 0.46), y - (s * 0.28), s * 0.2, 16)
        G.polygon(:fill, x - (s * 0.42), y - (s * 0.55), x + (s * 0.42), y - (s * 0.55), x + (s * 0.3), y + (s * 0.15),
                  x - (s * 0.3), y + (s * 0.15))
        G.rectangle(:fill, x - (s * 0.07), y + (s * 0.15), s * 0.14, s * 0.28)
        G.rectangle(:fill, x - (s * 0.3), y + (s * 0.43), s * 0.6, s * 0.14)
      end
    end

    # The Friend group screen, over the title's dimmed dots, as
    # Presentation::GroupScreen lays it out, and the short message a theft
    # or a win shows on the title or at Game Over.
    class GroupPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        plan = show.group_plan
        palette = pen.palette
        heading = pen.fonts.bold(plan.heading_size)
        words = Presentation::GroupWords.heading
        icon_x = layout.center_x - (heading.width(words) / 2.0) - (heading.height * 0.6)
        TrophyIcon.new(pen:).draw(icon_x, plan.heading_y, heading.height)
        pen.text(words, heading, layout.center_x, plan.heading_y, palette.cream)
        lines(plan, layout)
        fields(show, plan)
        buttons(show, plan.actions)
        plan.rows.each { row(show, plan, it) }
        hold(show, layout) if show.group_panel.hold.held?
      end

      # The message at +y+, centred on a dark pill so it reads over
      # anything, for the moment it shows. +banner+ is nil most of the time.
      def banner(banner, now, layout, y)
        return unless banner

        alpha = banner.alpha(now)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(layout.scaled(pen.look::GROUPS.text)))
        width = font.width(banner.text) + (font.height * 3.0)
        height = font.height * 1.9
        pixels = pen.pixels
        x = pixels.snap(layout.center_x - (width / 2.0))
        top = pixels.snap(y)
        pen.color(pen.palette.ink_bottom, 0.94 * alpha)
        G.rectangle(:fill, x, top, width, height, height / 2.0, height / 2.0, 32)
        TrophyIcon.new(pen:).draw(x + (height * 0.65), top + (height / 2.0), height * 0.75, alpha)
        pen.text(banner.text, font, x + (width / 2.0) + (height * 0.3), top + (height / 2.0), pen.palette.cream, alpha)
      end

      private

      def lines(plan, layout)
        palette = pen.palette
        font = pen.fonts.semibold(plan.size)
        colors = { text: palette.cream, note: palette.soft, alert: palette.alarm }
        plan.lines.each { pen.text(it.text, font, layout.center_x, it.y, colors.fetch(it.kind)) }
      end

      def fields(show, plan)
        plan.fields.each { |name, rect| field(show, name, rect, plan.size) }
      end

      def field(show, name, rect, size)
        panel = show.group_panel
        words = Presentation::GroupWords
        font = pen.fonts.semibold(size)
        hover = show.hover.level(:"group_#{name}")
        focused = panel.focus == name
        draw_box(rect, focused ? 0.8 : hover)
        label = name == :name ? words.name_label : words.code_label
        value = name == :name ? panel.name : panel.code
        pen.text(label, font, rect.x + (rect.height * 0.5) + (font.width(label) / 2.0), rect.center_y, pen.palette.soft)
        x = rect.x + (rect.height * 0.5) + font.width(label) + (rect.height * 0.5)
        text = value + (focused && (show.now * 2).floor.even? ? "|" : "")
        pen.text(text, font, x + (font.width(text) / 2.0), rect.center_y, pen.palette.cream)
      end

      # A typing field: a box a bit darker than a button, its edge lit
      # while it has the keyboard.
      def draw_box(rect, lit)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        pen.color(pen.palette.ink_bottom, 0.85)
        G.rectangle(:fill, x, y, width, height, height / 3.0, height / 3.0, 24)
        pen.color(pen.palette.soft.mix(pen.look::HOVER.edge, lit.clamp(0.0, 1.0)), 0.6 + (0.4 * lit.clamp(0.0, 1.0)))
        G.line_width = pixels.line_width(lit > 0.5 ? 2 : 1)
        G.rectangle(:line, x, y, width, height, height / 3.0, height / 3.0, 24)
      end

      def buttons(show, actions)
        actions.each do |action|
          PillButton.new(pen:).draw(action.rect, action.text, hover: show.hover.level(action.name),
                                    color: quiet?(action.name) ? pen.palette.soft : pen.palette.cream)
        end
      end

      def quiet?(name) = name.is_a?(Array) || %i[group_delete group_leave].include?(name)

      def row(show, plan, row)
        font = pen.fonts.semibold(plan.size)
        rect = row.rect
        x = rect.x + rect.height * (row.holder ? 0.75 : 0.25)
        room = row.actions.map { it.rect.x }.min || rect.right
        name = row.name
        name = name[0..-2] while name.size > 3 && x + font.width(name) > room - (rect.height * 0.2)
        TrophyIcon.new(pen:).draw(rect.x + (rect.height * 0.35), rect.center_y, rect.height * 0.8) if row.holder
        pen.text(name, font, x + (font.width(name) / 2.0), rect.center_y, pen.palette.cream)
        buttons(show, row.actions)
      end

      # While a long press is held, what it will do.
      def hold(show, layout)
        font = pen.fonts.semibold(layout.scaled(pen.look::GROUPS.text))
        y = layout.records_floor - (font.height * 2)
        pen.text(show.group_panel.holding_words, font, layout.center_x, y, pen.palette.cream)
      end
    end
  end
end
