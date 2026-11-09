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

    # The friend groups' screens, over the title's dimmed dots, as
    # Presentation::GroupScreen lays them out, and the short announcement a
    # title change shows on the title or at Game Over.
    class GroupPainter < Data.define(:pen, :icons)
      G = ::Lota::Graphics

      def initialize(pen:, icons: MemberIconPainter.new(pen:)) = super

      def draw(show, layout)
        plan = show.group_plan
        palette = pen.palette
        heading = pen.fonts.bold(plan.heading_size)
        icon_x = plan.heading_x - (heading.width(plan.heading) / 2.0) - (heading.height * 0.6)
        TrophyIcon.new(pen:).draw(icon_x, plan.heading_y, heading.height)
        pen.text(plan.heading, heading, plan.heading_x, plan.heading_y, palette.cream)
        lines(plan, layout)
        code_box(show, plan)
        buttons(show, plan)
        plan.rows.each { row(show, plan, it) }
        hold(show, layout) if show.group_panel.hold.held?
      end

      # The announcement at +y+, on a dark pill so it reads over anything,
      # for the moment it shows, with the group's crest and the champion's
      # icon. +banner+ is nil most of the time.
      def banner(banner, now, layout, y)
        return unless banner

        alpha = banner.alpha(now)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(layout.scaled(pen.look::GROUPS.text)))
        height = font.height * 1.9
        width = font.width(banner.text) + (height * 2.7)
        pixels = pen.pixels
        x = pixels.snap(layout.center_x - (width / 2.0))
        top = pixels.snap(y)
        middle = top + (height / 2.0)
        pen.color(pen.palette.ink_bottom, 0.94 * alpha)
        G.rectangle(:fill, x, top, width, height, height / 2.0, height / 2.0, 32)
        icons.crest(x + (height * 0.55), middle, height * 0.34, banner.group_id, alpha)
        icons.draw(x + (height * 1.2), middle, height * 0.34, banner.group_id, banner.number, alpha)
        pen.text(banner.text, font, x + (height * 1.7) + (font.width(banner.text) / 2.0), middle, pen.palette.cream, alpha)
      end

      private

      def lines(plan, layout)
        palette = pen.palette
        font = pen.fonts.semibold(plan.size)
        colors = { text: palette.cream, note: palette.soft, alert: palette.alarm }
        plan.lines.each { pen.text(it.text, font, layout.center_x, it.y, colors.fetch(it.kind)) }
      end

      # The code tapped so far, with a dash for each digit still to come.
      def code_box(show, plan)
        rect = plan.code_box or return
        panel = show.group_panel
        text = Presentation::CodeText.of(panel.code, Presentation::GroupWords::CODE_LENGTH)
        CodeBox.new(pen:).draw(rect, text, pen.fonts.semibold(plan.size), empty: panel.code.empty?)
      end

      # Every button but a row's: a row is drawn as a row.
      def buttons(show, plan)
        plan.actions.each do |action|
          next unless action.text

          PillButton.new(pen:).draw(action.rect, action.text, hover: show.hover.level(action.name),
                                    color: quiet?(action.name) ? pen.palette.soft : pen.palette.cream)
        end
      end

      def quiet?(name) = %i[group_delete group_leave].include?(name)

      def row(show, plan, row)
        case row
        in Presentation::GroupListRow then list_row(show, plan, row)
        in Presentation::GroupStandingRow then standing_row(plan, row)
        in Presentation::GroupHistoryRow then history_row(plan, row)
        end
      end

      # A group's crest, its champion and score, and how many are in it.
      def list_row(show, plan, row)
        rect = row.rect
        group = row.group
        font = pen.fonts.semibold(plan.size)
        radius = rect.height * 0.38
        backing(rect, show.hover.level([:group_show, group.id]))
        icons.crest(rect.x + (radius * 1.4), rect.center_y, radius, group.id)
        members = Presentation::GroupWords.members(group.members.size)
        pen.text(members, font, rect.x + (radius * 2.6) + (font.width(members) / 2.0), rect.center_y, pen.palette.soft)
        right = rect.right - radius
        score = group.top_score.to_s
        pen.text(score, font, right - (font.width(score) / 2.0), rect.center_y, pen.palette.cream)
        return if group.vacant?

        x = right - font.width(score) - (radius * 1.2)
        icons.draw(x, rect.center_y, radius * 0.85, group.id, group.champion_number)
        TrophyIcon.new(pen:).draw(x - (radius * 1.7), rect.center_y, rect.height * 0.62) if group.champion?
      end

      def standing_row(plan, row)
        font = pen.fonts.semibold(plan.size)
        rect = row.rect
        radius = rect.height * 0.42
        backing(rect, row.me ? 0.5 : 0.0) if row.champion || row.me
        icons.draw(rect.x + (radius * 1.25), rect.center_y, radius, row.group_id, row.number)
        x = rect.x + (radius * 2.7)
        if row.me
          pen.text(Presentation::GroupWords.you, font, x + (font.width(Presentation::GroupWords.you) / 2.0), rect.center_y, pen.palette.cream)
          x += font.width(Presentation::GroupWords.you) + (radius * 0.5)
        end
        champion(font, x, rect) if row.champion
        score = row.score.to_s
        color = row.champion ? pen.palette.fresh_light : pen.palette.cream
        pen.text(score, pen.fonts.bold(plan.size), rect.right - radius - (font.width(score) / 2.0), rect.center_y, color)
      end

      def champion(font, x, rect)
        TrophyIcon.new(pen:).draw(x + (rect.height * 0.3), rect.center_y, rect.height * 0.72)
        word = Presentation::GroupWords.champion
        pen.text(word, font, x + (rect.height * 0.7) + (font.width(word) / 2.0), rect.center_y, pen.palette.fresh_light)
      end

      # The new champion, beside whom they took it from (or a trophy for
      # the first ever), the score and the day.
      def history_row(plan, row)
        font = pen.fonts.semibold(plan.size)
        rect = row.rect
        change = row.change
        radius = rect.height * 0.38
        y = rect.center_y
        icons.draw(rect.x + (radius * 1.1), y, radius, row.group_id, change.champion_number)
        pen.color(pen.palette.soft)
        G.polygon(:fill, rect.x + (radius * 2.6), y, rect.x + (radius * 3.2), y - (radius * 0.4), rect.x + (radius * 3.2), y + (radius * 0.4))
        if change.previous_champion_number
          icons.draw(rect.x + (radius * 4.5), y, radius, row.group_id, change.previous_champion_number)
        else
          TrophyIcon.new(pen:).draw(rect.x + (radius * 4.5), y, rect.height * 0.7)
        end
        score = change.score.to_s
        pen.text(score, font, rect.x + (radius * 6.4) + (font.width(score) / 2.0), y, pen.palette.cream)
        date = change.date
        pen.text(date, font, rect.right - (font.width(date) / 2.0), y, pen.palette.soft) if date
      end

      def backing(rect, lit)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        pen.color(pen.palette.ink_bottom, 0.5 + (0.3 * lit))
        G.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 32)
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
