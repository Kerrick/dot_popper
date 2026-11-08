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

    # A mark (Groups::Mark) drawn as Presentation::Look::MARKS says: a dot
    # in the mark's colour with its dark shape on it, +radius+ across from
    # +x+, +y+. +chosen+ rings it in cream, so which one is worn shows
    # without a word.
    class MarkIcon < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(x, y, radius, mark, alpha = 1.0, chosen: false)
        look = pen.look::MARKS.fetch(mark)
        pen.color(look.color, alpha)
        G.circle(:fill, x, y, radius, 32)
        if chosen
          pen.color(pen.palette.cream, alpha)
          G.line_width = pen.pixels.line_width(2)
          G.circle(:line, x, y, radius + (radius * 0.14), 32)
        end
        pen.color(pen.palette.ink_bottom, alpha)
        G.line_width = pen.pixels.line_width(2)
        shape(look.shape, x, y, radius * 0.5)
      end

      private

      def shape(name, x, y, r)
        case name
        when :ring then G.circle(:line, x, y, r * 0.8, 24)
        when :plus then (G.line(x - r, y, x + r, y) && G.line(x, y - r, x, y + r))
        when :cross then (G.line(x - (r * 0.8), y - (r * 0.8), x + (r * 0.8), y + (r * 0.8)) && G.line(x - (r * 0.8), y + (r * 0.8), x + (r * 0.8), y - (r * 0.8)))
        when :triangle then G.polygon(:fill, x, y - r, x + r, y + (r * 0.8), x - r, y + (r * 0.8))
        when :square then G.rectangle(:fill, x - (r * 0.75), y - (r * 0.75), r * 1.5, r * 1.5)
        when :diamond then G.polygon(:fill, x, y - r, x + r, y, x, y + r, x - r, y)
        when :bar then G.rectangle(:fill, x - r, y - (r * 0.25), r * 2, r * 0.5)
        when :pair then (G.circle(:fill, x - (r * 0.55), y, r * 0.38, 16) && G.circle(:fill, x + (r * 0.55), y, r * 0.38, 16))
        end
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
        code_box(show, plan)
        buttons(show, plan.actions)
        plan.rows.each { row(plan, it) }
        hold(show, layout) if show.group_panel.hold.held?
      end

      # The message at +y+, centred on a dark pill so it reads over
      # anything, for the moment it shows. +banner+ is nil most of the time.
      def banner(banner, now, layout, y)
        return unless banner

        alpha = banner.alpha(now)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(layout.scaled(pen.look::GROUPS.text)))
        icon = banner.mark ? 1.6 : 0.0
        width = font.width(banner.text) + (font.height * (3.0 + icon))
        height = font.height * 1.9
        pixels = pen.pixels
        x = pixels.snap(layout.center_x - (width / 2.0))
        top = pixels.snap(y)
        pen.color(pen.palette.ink_bottom, 0.94 * alpha)
        G.rectangle(:fill, x, top, width, height, height / 2.0, height / 2.0, 32)
        TrophyIcon.new(pen:).draw(x + (height * 0.65), top + (height / 2.0), height * 0.75, alpha)
        MarkIcon.new(pen:).draw(x + (width - (height * 0.7)), top + (height / 2.0), height * 0.32, banner.mark, alpha) if banner.mark
        pen.text(banner.text, font, x + (height * 1.1) + (font.width(banner.text) / 2.0), top + (height / 2.0), pen.palette.cream, alpha)
      end

      private

      def lines(plan, layout)
        palette = pen.palette
        font = pen.fonts.semibold(plan.size)
        colors = { text: palette.cream, note: palette.soft, alert: palette.alarm }
        plan.lines.each { pen.text(it.text, font, layout.center_x, it.y, colors.fetch(it.kind)) }
      end

      # The code tapped so far, in a box, as the dots of a code not yet
      # complete: tapped digits in cream, the rest as soft dashes.
      def code_box(show, plan)
        rect = plan.code_box or return
        font = pen.fonts.semibold(plan.size)
        draw_box(rect, show.hover.level(:group_code))
        code = show.group_panel.code
        total = Presentation::GroupWords::CODE_LENGTH
        text = code + ("-" * (total - code.size))
        pen.text(text.chars.join(" "), font, rect.center_x, rect.center_y, code.empty? ? pen.palette.soft : pen.palette.cream)
      end

      # A box a bit darker than a button.
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
          next mark_button(show, action) if action.name.is_a?(Array) && action.name.first == :group_mark

          PillButton.new(pen:).draw(action.rect, action.text, hover: show.hover.level(action.name),
                                    color: quiet?(action.name) ? pen.palette.soft : pen.palette.cream)
        end
      end

      def quiet?(name) = %i[group_delete group_leave].include?(name)

      # A dot to wear: a mark, ringed when it is the one picked.
      def mark_button(show, action)
        rect = action.rect
        mark = action.name.last
        lit = show.hover.level(action.name)
        radius = (rect.width / 2.0) * (0.86 + (0.1 * lit))
        MarkIcon.new(pen:).draw(rect.center_x, rect.center_y, radius, mark, chosen: show.group_panel.mark == mark)
      end

      def row(plan, row)
        font = pen.fonts.semibold(plan.size)
        rect = row.rect
        radius = rect.height * 0.4
        MarkIcon.new(pen:).draw(rect.x + radius, rect.center_y, radius, row.mark)
        x = rect.x + (radius * 2.8)
        if row.me
          pen.text(Presentation::GroupWords.you, font, x + (font.width(Presentation::GroupWords.you) / 2.0), rect.center_y, pen.palette.cream)
          x += font.width(Presentation::GroupWords.you) + (radius * 0.8)
        end
        TrophyIcon.new(pen:).draw(x + (rect.height * 0.35), rect.center_y, rect.height * 0.8) if row.holder
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
