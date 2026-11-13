# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the friend groups' screens, in graphics units at a scale
    # of 1: its heading's and its text's type, the widest its column gets,
    # and how dark Home's dots go behind it.
    class GroupStyle < Data.define(:heading, :text, :column, :veil); end

    # A line of words where the screen puts it: +kind+ is :text, :note or
    # :alert, and says how it reads.
    class GroupLine < Data.define(:text, :y, :kind); end

    # A button the screen offers: +name+ is what Show#tap hears. A row that
    # opens a group has no text of its own.
    class GroupAction < Data.define(:name, :rect, :text); end

    # A row of the list of groups, which opens the group.
    class GroupListRow < Data.define(:rect, :group); end

    # A member's row in the standings: their +rank+ among the group's, and
    # whether they hold the title and are this player.
    class GroupStandingRow < Data.define(:rect, :group_id, :number, :score, :rank, :champion, :me); end

    # An entry in a group's history: a title change (Groups::TitleChange)
    # or a member's achievement (Groups::MemberAchievement).
    class GroupHistoryRow < Data.define(:rect, :group_id, :change); end

    # Where a friend groups' screen's parts go: its text's +size+, the
    # heading (+heading+ its words, +heading_y+ its middle, +heading_size+
    # its type) and the line under it, its lines (GroupLine), the box of
    # the code (a Rect, or nil), its buttons (GroupAction, CodeKey), its
    # rows, the +window+ they scroll in and how tall all of them are
    # (+content+), and where the group's crest goes under its name.
    class GroupPlan < Data.define(:size, :heading, :heading_x, :heading_y, :heading_size, :lines, :code_box, :actions, :rows, :window, :content,
                                  :subheading, :crest_y)
      def controls = actions.map { [it.name, it.rect] }
    end

    # The friend groups' screens laid out under their heading and over
    # Back, as the redesign draws them: the list of the player's groups,
    # a group's standings with its code and History and Leave, its
    # history, and the keypad that joins one. Lists scroll (+offset+ down
    # from their top) in their +window+; the screen says how tall their
    # +content+ is. Every button is a thumb's height, and Leave sits apart
    # from the rest. Nothing on it is typed. On a controller (+input+) each
    # button names the one that presses it, and the list and a group add
    # the buttons that have no place of their own: the list's first group
    # (RB), and the previous and next group (LB, RB).
    class GroupScreen < Data.define(:layout, :style, :measure, :panel, :fixed_dots, :back_text, :offset, :input)
      TALL = 520.0 # the safe height, in points, a keypad column needs

      def initialize(layout:, style:, measure:, panel:, fixed_dots:, back_text:, offset: 0.0, input: InputKind::MOUSE) = super

      def plan
        case panel.page
        when :group then group_plan
        when :history then history_plan
        when :join then join_plan
        else list_plan
        end
      end

      private

      def size = layout.phone? ? 16 : 18
      def button = layout.control_height
      def gap = 10.0
      def page = layout.page
      def column_width = [page.width, 720.0].min
      def left = layout.center_x - (column_width / 2.0)
      def line_height = size * 1.4
      def row_height = layout.phone? ? 60.0 : 68.0
      def short? = layout.safe.height < TALL && layout.safe.width > layout.safe.height

      def back_action = GroupAction.new(name: :back, rect: layout.back_button, text: back_text)
      def gamepad? = input == InputKind::GAMEPAD
      def by(word, button) = GroupWords.pressed_by(word, button, input)

      # A pill in Back's row at the right edge, as wide as +text+ needs.
      def right_of_back(name, text)
        room = layout.safe.right - layout.page_margin - layout.back_button.right - layout.page_margin
        width = [measure.width(:semibold, (button * PillLabel::RATIO).round, text) + (button * 0.7), room].min # the word shrinks to fit the rest
        GroupAction.new(name:, text:, rect: Rect.new(x: layout.safe.right - layout.page_margin - width, y: layout.back_button.y, width:, height: button))
      end

      # LB and RB, the previous and the next group, at the right of Back's
      # row, on a controller, where there is another group to go to.
      def steps
        return [] unless gamepad? && panel.groups.groups.size > 1

        width = button * 1.3
        right = layout.safe.right - layout.page_margin
        y = layout.back_button.y
        [GroupAction.new(name: :group_prev, text: "LB", rect: Rect.new(x: right - (2 * width) - 8, y:, width:, height: button)),
         GroupAction.new(name: :group_next, text: "RB", rect: Rect.new(x: right - width, y:, width:, height: button))]
      end
      def alert_text = panel.note || (panel.groups.error && GroupWords.error(panel.groups.error))

      def wrapped(text, y, kind, room = column_width)
        Words.balance(text, room) { measure.width(:semibold, size, it) }
             .each_with_index.map { |line, i| GroupLine.new(text: line, y: y + (line_height * i), kind:) }
      end

      def plan_with(heading:, lines:, actions:, rows: [], code_box: nil, window: nil, content: 0.0, subheading: nil, crest_y: nil)
        GroupPlan.new(size:, heading:, heading_x: layout.center_x, heading_y: layout.heading_y, heading_size: layout.heading_size, lines:,
                      code_box:, actions:, rows:, window:, content:, subheading:, crest_y:)
      end

      # A row of equal pills across the column, at +y+.
      def row_of(y, actions)
        each = (column_width - (gap * (actions.size - 1))) / actions.size
        actions.each_with_index.map { |(name, text), i| GroupAction.new(name:, text:, rect: Rect.new(x: left + ((each + gap) * i), y:, width: each, height: button)) }
      end

      # +items+ as rows +height+ tall, a gap apart, scrolled +offset+ down
      # inside +window+, each placed by the block; only those that show,
      # and the content's whole height.
      def scrolled(items, window, height)
        pitch = height + 8.0
        rows = items.each_with_index.filter_map do |item, i|
          rect = Rect.new(x: left, y: window.y + (i * pitch) - offset, width: column_width, height:)
          yield item, rect if rect.bottom > window.y && rect.y < window.bottom
        end
        [rows, [(items.size * pitch) - 8.0, 0.0].max]
      end

      # A row's place a press reaches: what of it shows in the window.
      def seen(rect, window) = rect.cut(top: window.y, bottom: window.bottom)

      def list_plan
        groups = panel.listed
        action_y = page.bottom - button
        alert = alert_text ? wrapped(alert_text, action_y - line_height, :alert) : []
        bottom = (alert.first ? alert.first.y - (line_height / 2.0) : action_y) - gap
        lines = groups.empty? ? wrapped(GroupWords.blurb, page.y + line_height, :text) : []
        window = Rect.new(x: left, y: page.y, width: column_width, height: [bottom - page.y, 0.0].max)
        rows, content = scrolled(groups, window, row_height) { |group, rect| GroupListRow.new(rect:, group:) }
        opens = rows.map { GroupAction.new(name: [:group_show, it.group.id], rect: seen(it.rect, window), text: nil) }
        plan_with(heading: GroupWords.heading, lines: lines + alert, rows:, window:, content:,
                  actions: [*opens, *row_of(action_y, [[:group_join_open, by(GroupWords.join, "X")], [:group_create, by(GroupWords.create, "Y")]]),
                            *([right_of_back(:group_open_first, by(GroupWords.open_group, "RB"))] if gamepad? && groups.any?), back_action])
      end

      def group_plan
        group = panel.group or return list_plan
        crest = layout.short? ? 0.0 : 44.0
        title_y = page.y + crest + (line_height / 2.0)
        lines = wrapped(GroupWords.title_line(group), title_y, :text)
        lines += wrapped(alert_text || GroupWords.fixed_note, lines.last.y + line_height, alert_text ? :alert : :note) if alert_text || fixed_dots
        buttons_y = page.bottom - button
        code = Rect.new(x: left, y: buttons_y - gap - (button + 12), width: column_width, height: button + 12)
        top = lines.last.y + (line_height * 0.8)
        window = Rect.new(x: left, y: top, width: column_width, height: [code.y - gap - top, 0.0].max)
        rows, content = scrolled(group.standings.each_with_index.to_a, window, row_height - 6) do |(member, rank), rect|
          GroupStandingRow.new(rect:, group_id: group.id, number: member.number, score: member.top_score, rank: rank + 1,
                               champion: member.number == group.champion_number, me: member.number == group.you)
        end
        reveal_text = by(panel.code_shown? ? GroupWords.copy : GroupWords.show, "X")
        reveal_width = [92.0, measure.width(:semibold, ((button - 4) * PillLabel::RATIO).round, reveal_text) + (button * 0.7)].max
        reveal = GroupAction.new(name: :group_code, text: reveal_text,
                                 rect: Rect.new(x: code.right - 8 - reveal_width, y: code.y + 8, width: reveal_width, height: code.height - 16))
        leave = gamepad? ? GroupWords.hold_start_to_leave : GroupWords.leave
        plan_with(heading: Names.group(group.id), lines:, rows:, window:, content:, code_box: code, crest_y: (page.y + 18.0 unless layout.short?),
                  actions: [reveal, *row_of(buttons_y, [[:group_history, by(GroupWords.history, "Y")], [:group_leave, leave]]), *steps, back_action])
      end

      def history_plan
        group = panel.group or return list_plan
        entries = panel.history_entries
        lines = entries.empty? ? wrapped(GroupWords.no_history, page.y + line_height + 20, :note) : []
        top = page.y + 22.0
        window = Rect.new(x: left, y: top, width: column_width, height: [page.bottom - top, 0.0].max)
        rows, content = scrolled(entries, window, row_height + 8) { |entry, rect| GroupHistoryRow.new(rect:, group_id: group.id, change: entry) }
        plan_with(heading: GroupWords.history_heading, subheading: Names.group(group.id), lines:, rows:, window:, content:, actions: [back_action])
      end

      def pad(rect) = CodePad.new(rect:, gap: 8.0, key_height: [button + 18, 74.0].min, erase: by(GroupWords.erase, "X"), submit: by(GroupWords.submit, "Start"))
      def pad_height(room) = [CodePad.height([button + 18, 74.0].min, 8.0), room].min

      def join_plan = short? ? join_beside : join_stacked

      def join_stacked
        room = page.height - button - (gap * 2)
        keys_height = pad_height(room)
        top = page.bottom - keys_height
        box = Rect.new(x: left, y: top - gap - button, width: column_width, height: button)
        message = alert_text ? wrapped(alert_text, box.y - line_height, :alert) : []
        keys = pad(Rect.new(x: left, y: top, width: column_width, height: keys_height)).keys
        plan_with(heading: GroupWords.join_heading, lines: message, code_box: box, actions: [*keys, back_action])
      end

      def join_beside
        each = [(page.width - gap) / 2.0, column_width].min
        x = layout.center_x - (((2 * each) + gap) / 2.0)
        box = Rect.new(x:, y: page.center_y - (button / 2.0), width: each, height: button)
        message = alert_text ? wrapped(alert_text, box.bottom + line_height, :alert, each) : []
        keys = pad(Rect.new(x: x + each + gap, y: page.y, width: each, height: pad_height(page.height))).keys
        plan_with(heading: GroupWords.join_heading, lines: message, code_box: box, actions: [*keys, back_action])
      end
    end

    # Where the notice of a first Join or Create puts its parts: its
    # +card+, the sentence's +lines+ (+size+ their type, the first's middle
    # at +text_y+, +line_height+ apart), the link to the privacy policy
    # (+policy+, its words +policy_text+ in type +link_size+), Not now (+later+) and the button
    # that goes on (+go+).
    class GroupNoticePlan < Data.define(:card, :lines, :size, :text_y, :line_height, :policy, :policy_text, :link_size, :later, :go)
      def controls = [[:policy, policy], [:notice_later, later], [:notice_go, go]]
    end

    # The notice, as a dialog over the friend groups' screen: centered in
    # the safe area, no wider than 520, the sentence balanced over its
    # lines, the link under it, and Not now beside the button that goes on,
    # which takes the larger share.
    class GroupNoticeDialog < Data.define(:layout, :measure, :policy_text, :later_text, :go_text)
      PAD = 26.0
      LINK = 18 # the link's type size

      def plan
        safe = layout.safe
        width = [safe.width - (2 * layout.page_margin), 520.0].min
        room = width - (2 * PAD)
        lines = Words.balance(GroupWords.notice, room) { measure.width(:bold, size, it) }
        line_height = size * 1.3
        button = layout.control_height
        link = LINK * 2.0
        later_width = [(room - 12) * 0.42, label(later_text, button)].max
        stacked = label(go_text, button) > room - later_width - 12
        height = PAD + (lines.size * line_height) + 12 + link + 16 + button + (stacked ? button + 10 : 0) + PAD
        top = safe.y + [(safe.height - height) / 2.0, 8.0].max
        card = Rect.new(x: layout.center_x - (width / 2.0), y: top, width:, height:)
        link_size = LINK
        link_size -= 1 while link_size > 12 && measure.width(:semibold, link_size, policy_text) + 34 > room
        link_width = measure.width(:semibold, link_size, policy_text) + 34
        policy = Rect.new(x: layout.center_x - (link_width / 2.0), y: top + PAD + (lines.size * line_height) + 12, width: link_width, height: link)
        row = card.bottom - PAD - button
        if stacked # too narrow for both words side by side: the one that goes on first
          later = Rect.new(x: card.x + PAD, y: row, width: room, height: button)
          go = Rect.new(x: card.x + PAD, y: row - 10 - button, width: room, height: button)
        else
          later = Rect.new(x: card.x + PAD, y: row, width: later_width, height: button)
          go = Rect.new(x: later.right + 12, y: row, width: room - later_width - 12, height: button)
        end
        GroupNoticePlan.new(card:, lines:, size:, text_y: top + PAD + (line_height / 2.0), line_height:, policy:, policy_text:, link_size:, later:, go:)
      end

      private

      def size = layout.phone? ? 19 : 21

      # How wide a button must be for +text+ at its full size, with its
      # rounded ends' room.
      def label(text, height) = measure.width(:bold, (height * 0.36).round, text) + height # as Shell::PrimaryButton sizes it
    end
  end
end
