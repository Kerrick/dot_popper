# frozen_string_literal: true

module DotPopper
  module Shell
    # The friend groups' screens, over Home's dimmed dots, as
    # Presentation::GroupScreen lays them out, each under its heading with
    # Back, and the short announcement a title change shows on Home or at
    # Game Over.
    class GroupPainter < Data.define(:pen, :icons)
      G = ::Lota::Graphics

      def initialize(pen:, icons: MemberIconPainter.new(pen:)) = super

      def draw(show, layout)
        plan = show.group_plan
        palette = pen.palette
        heading = pen.fonts.bold(show.heading_place(plan.heading).first)
        pen.text(plan.heading, heading, plan.heading_x, plan.heading_y, palette.cream)
        PillButton.new(pen:).draw(layout.back_button, show.words.go_back, hover: show.hover.level(:back),
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(:chevron_left, x, y, size * 0.38) })
        pen.text(plan.subheading, pen.fonts.semibold(15), layout.center_x, plan.heading_y + (heading.height * 0.62), palette.soft) if plan.subheading
        icons.crest(layout.center_x, plan.crest_y, 22.0, show.group_panel.group_id) if plan.crest_y && show.group_panel.group_id
        lines(plan, layout)
        show.group_panel.page == :group ? code_row(show, plan) : code_box(show, plan)
        buttons(show, plan)
        rows(show, plan)
        hold(show, layout) if show.group_panel.hold.held?
      end

      # The rows, clipped to the window they scroll in.
      def rows(show, plan)
        window = plan.window
        pixels = pen.pixels
        G.scissor = pixels.snap(window.x - 4), pixels.snap(window.y), pixels.snap(window.width + 8), pixels.snap(window.height) if window
        plan.rows.each { row(show, plan, it) }
        G.scissor = nil
      end

      # The announcement at +y+, on a dark pill so it reads over anything,
      # for the moment it shows, with the group's crest and the champion's
      # icon. +banner+ is nil most of the time.
      def banner(banner, now, layout, y)
        return unless banner

        alpha = banner.alpha(now)
        font = pen.fonts.semibold(Presentation::Pixels.font_size(layout.scaled(pen.style::GROUPS.text)))
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

      # The code tapped so far, one box for each of its seven places, a
      # hyphen after the third, as a code is shared: 482-1073. The next
      # place to fill is outlined, and a place still to come shows a dash.
      def code_box(show, plan)
        rect = plan.code_box or return
        panel = show.group_panel
        places = Presentation::CodeText.places(panel.code, Presentation::GroupWords::CODE_LENGTH)
        gap = 6.0
        hyphen = rect.height * 0.35
        width = [(rect.width - hyphen - (gap * places.size)) / places.size, rect.height * 0.85].min
        x = rect.center_x - (((width * places.size) + hyphen + (gap * places.size)) / 2.0)
        font = pen.fonts.bold((rect.height * 0.5).round)
        places.each_with_index do |digit, i|
          if i == Presentation::CodeText::FIRST
            pen.text("-", font, x + (hyphen / 2.0), rect.center_y, pen.palette.soft)
            x += hyphen + gap
          end
          box = Presentation::Rect.new(x:, y: rect.y, width:, height: rect.height)
          Card.new(pen:).draw(box, corner: 10.0, edge: (pen.palette.cream if i == panel.code.size))
          pen.text(digit || "–", font, box.center_x, box.center_y, digit ? pen.palette.cream : pen.palette.soft)
          x += width + gap
        end
      end

      # Every button but a row's: a row is drawn as a row, the keypad's
      # keys as keys, and the code's Show or Copy in its row.
      SIGNS = { group_join_open: :keypad, group_create: :plus, group_history: :history, group_leave: :leave, group_code: nil }.freeze

      def buttons(show, plan)
        plan.actions.each do |action|
          next if !action.text || action.name == :back
          next key(show, action) if key?(action.name)

          sign = SIGNS[action.name]
          leave = action.name == :group_leave
          color = leave ? pen.palette.alarm : pen.palette.cream
          icon = (->(x, y, size) { Glyphs.new(pen:).draw(sign, x, y, size * 0.4, color:) } if sign)
          PillButton.new(pen:).draw(action.rect, action.text, hover: show.hover.level(action.name), color:, icon:, edge: (pen.palette.alarm if leave))
        end
      end

      # The group's code, hidden until Show is pressed: "Code", the code or
      # its dots, and Show or Copy at the row's end.
      def code_row(show, plan)
        rect = plan.code_box or return
        panel = show.group_panel
        Card.new(pen:).draw(rect)
        small = pen.fonts.semibold(15)
        pen.text("Code", small, rect.x + 18 + (small.width("Code") / 2.0), rect.center_y, pen.palette.soft)
        code = panel.code_shown? ? Presentation::CodeText.hyphenated(panel.group.join_code) : Presentation::GroupWords.hidden_code
        font = pen.fonts.bold(24)
        pen.text(code, font, rect.center_x, rect.center_y, pen.palette.cream)
      end

      def key?(name) = (name in [:code_digit, String] | :code_erase | :code_submit)

      # A key of the keypad: a digit, Delete with its sign, or Join, which
      # looks disabled until all seven digits are in.
      def key(show, action)
        rect = action.rect
        open = action.name != :code_submit || show.group_panel.code_complete?
        hover = open ? show.hover.level(action.name) : 0.0
        Card.new(pen:).draw(rect, corner: [rect.height * 0.22, 14.0].min, alpha: open ? 1.0 : 0.5, lit: hover)
        digit = action.name.is_a?(Array)
        font = digit ? pen.fonts.bold((rect.height * 0.42).round) : pen.fonts.semibold((rect.height * 0.3).round)
        color = open ? pen.palette.cream : pen.palette.soft
        return pen.text(action.text, font, rect.center_x, rect.center_y, color, open ? 1.0 : 0.6) unless action.name == :code_erase

        mark = rect.height * 0.36
        left = rect.center_x - ((mark + 8 + font.width(action.text)) / 2.0)
        Glyphs.new(pen:).draw(:backspace, left + (mark / 2.0), rect.center_y, mark)
        pen.text(action.text, font, left + mark + 8 + (font.width(action.text) / 2.0), rect.center_y, color)
      end

      def quiet?(name) = %i[group_delete group_leave].include?(name)

      def row(show, plan, row)
        case row
        in Presentation::GroupListRow then list_row(show, plan, row)
        in Presentation::GroupStandingRow then standing_row(plan, row)
        in Presentation::GroupHistoryRow then history_row(plan, row)
        end
      end

      # A group's crest and name, a crown where the player holds its
      # title, its top score, and the arrow that opens it.
      def list_row(show, plan, row)
        rect = row.rect
        group = row.group
        Card.new(pen:).draw(rect, lit: show.hover.level([:group_show, group.id]))
        radius = rect.height * 0.32
        icons.crest(rect.x + 14 + radius, rect.center_y, radius, group.id)
        font = pen.fonts.bold(plan.size)
        name = Presentation::Names.group(group.id)
        pen.text(name, font, rect.x + 28 + (radius * 2) + (font.width(name) / 2.0), rect.center_y, pen.palette.cream)
        score = group.top_score.to_s
        big = pen.fonts.bold(plan.size + 8)
        right = rect.right - 46
        pen.text(score, big, right - (big.width(score) / 2.0), rect.center_y, pen.palette.fresh_body)
        Glyphs.new(pen:).draw(:chevron_right, rect.right - 22, rect.center_y, 16, color: pen.palette.soft)
        return unless group.champion?

        Glyphs.new(pen:).draw(:crown, right - big.width(score) - 26, rect.center_y, 24, color: pen.palette.fresh_body)
      end

      # A member's rank, icon and name, Champion or You under it, and their
      # score; the player's own row outlined.
      def standing_row(plan, row)
        rect = row.rect
        Card.new(pen:).draw(rect, edge: (pen.palette.fresh_body if row.me))
        small = pen.fonts.semibold(13)
        font = pen.fonts.bold(plan.size)
        rank = row.rank.to_s
        pen.text(rank, small, rect.x + 20, rect.center_y, pen.palette.soft)
        radius = rect.height * 0.32
        icons.draw(rect.x + 40 + radius, rect.center_y, radius, row.group_id, row.number)
        x = rect.x + 52 + (radius * 2)
        name = Presentation::Names.member(row.group_id, row.number)
        tag = (Presentation::GroupWords.champion if row.champion) || (Presentation::GroupWords.you if row.me)
        y = tag ? rect.center_y - (font.height * 0.38) : rect.center_y
        pen.text(name, font, x + (font.width(name) / 2.0), y, pen.palette.cream)
        if tag
          tag_x = x
          if row.champion
            Glyphs.new(pen:).draw(:crown, x + 8, rect.center_y + (font.height * 0.45), 14, color: pen.palette.fresh_body)
            tag_x += 20
          end
          pen.text(tag, small, tag_x + (small.width(tag) / 2.0), rect.center_y + (font.height * 0.45), pen.palette.fresh_body)
        end
        score = row.score.to_s
        big = pen.fonts.bold(plan.size + 6)
        pen.text(score, big, rect.right - 18 - (big.width(score) / 2.0), rect.center_y, pen.palette.cream)
      end

      # Who took the title from whom, or who earned which achievement, the
      # names in bold, and when, in the player's own time.
      def history_row(plan, row)
        rect = row.rect
        Card.new(pen:).draw(rect)
        change = row.change
        number = change.is_a?(Groups::MemberAchievement) ? change.member_number : change.champion_number
        radius = rect.height * 0.3
        icons.draw(rect.x + 14 + radius, rect.center_y, radius, row.group_id, number)
        left = rect.x + 28 + (radius * 2)
        room = rect.right - 14 - left
        bold = pen.fonts.bold(plan.size - 1)
        plain = pen.fonts.semibold(plan.size - 1)
        lines = runs_in_lines(Presentation::GroupWords.entry(row.group_id, change), room, bold, plain).first(2)
        small = pen.fonts.semibold(13)
        top = rect.center_y - (((lines.size * bold.height) + small.height) / 2.0)
        lines.each_with_index do |line, i|
          x = left
          line.each do |text, strong|
            face = strong ? bold : plain
            pen.text(text, face, x + (face.width(text) / 2.0), top + (bold.height * (i + 0.5)), strong ? pen.palette.cream : pen.palette.soft)
            x += face.width(text)
          end
        end
        stamp = Presentation::GroupWords.when(change.at)
        pen.text(stamp, small, left + (small.width(stamp) / 2.0), top + (lines.size * bold.height) + (small.height / 2.0), pen.palette.soft)
      end

      # Runs of [text, bold] broken into lines no wider than +room+, at
      # word boundaries.
      def runs_in_lines(runs, room, bold, plain)
        lines = [[]]
        width = 0.0
        runs.each do |text, strong|
          face = strong ? bold : plain
          text.split(/(?<= )/).each do |word|
            wide = face.width(word)
            if width + wide > room && !lines.last.empty?
              lines << []
              width = 0.0
              word = word.lstrip
              wide = face.width(word)
            end
            last = lines.last.last
            last && last[1] == strong ? last[0] += word : lines.last << [+word, strong]
            width += wide
          end
        end
        lines
      end

      def backing(rect, lit)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        pen.color(pen.palette.ink_bottom, 0.5 + (0.3 * lit))
        G.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 32)
      end

      # While a long press is held, what it will do.
      def hold(show, layout)
        font = pen.fonts.semibold(layout.scaled(pen.style::GROUPS.text))
        y = layout.page.bottom - layout.control_height - (font.height * 1.2)
        pen.text(show.group_panel.holding_words, font, layout.center_x, y, pen.palette.cream)
      end
    end
  end
end
