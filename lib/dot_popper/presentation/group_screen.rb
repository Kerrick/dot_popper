# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the friend groups' screens, in graphics units at a scale
    # of 1: its heading's and its text's type, the widest its column gets,
    # and how dark the title's dots go behind it.
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
    # from the rest. Nothing on it is typed.
    class GroupScreen < Data.define(:layout, :style, :measure, :panel, :standard_dots, :back_text, :offset)
      TALL = 520.0 # the safe height, in points, a keypad column needs

      def initialize(layout:, style:, measure:, panel:, standard_dots:, back_text:, offset: 0.0) = super

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
        groups = panel.groups.groups.sort_by { Names.group(it.id) }
        action_y = page.bottom - button
        alert = alert_text ? wrapped(alert_text, action_y - line_height, :alert) : []
        bottom = (alert.first ? alert.first.y - (line_height / 2.0) : action_y) - gap
        lines = groups.empty? ? wrapped(GroupWords.blurb, page.y + line_height, :text) : []
        lines += wrapped(GroupWords.privacy, lines.last.y + (line_height * 1.5), :note) if groups.empty?
        window = Rect.new(x: left, y: page.y, width: column_width, height: [bottom - page.y, 0.0].max)
        rows, content = scrolled(groups, window, row_height) { |group, rect| GroupListRow.new(rect:, group:) }
        opens = rows.map { GroupAction.new(name: [:group_show, it.group.id], rect: seen(it.rect, window), text: nil) }
        plan_with(heading: GroupWords.heading, lines: lines + alert, rows:, window:, content:,
                  actions: [*opens, *row_of(action_y, [[:group_join_open, GroupWords.join], [:group_create, GroupWords.create]]), back_action])
      end

      def group_plan
        group = panel.group or return list_plan
        crest = layout.short? ? 0.0 : 44.0
        title_y = page.y + crest + (line_height / 2.0)
        lines = wrapped(GroupWords.title_line(group), title_y, :text)
        lines += wrapped(alert_text || GroupWords.standard_note, lines.last.y + line_height, alert_text ? :alert : :note) if alert_text || standard_dots
        buttons_y = page.bottom - button
        code = Rect.new(x: left, y: buttons_y - gap - (button + 12), width: column_width, height: button + 12)
        top = lines.last.y + (line_height * 0.8)
        window = Rect.new(x: left, y: top, width: column_width, height: [code.y - gap - top, 0.0].max)
        rows, content = scrolled(group.standings.each_with_index.to_a, window, row_height - 6) do |(member, rank), rect|
          GroupStandingRow.new(rect:, group_id: group.id, number: member.number, score: member.top_score, rank: rank + 1,
                               champion: member.number == group.champion_number, me: member.number == group.you)
        end
        reveal = GroupAction.new(name: :group_code, text: panel.code_shown? ? GroupWords.copy : GroupWords.show,
                                 rect: Rect.new(x: code.right - 8 - 92, y: code.y + 8, width: 92, height: code.height - 16))
        plan_with(heading: Names.group(group.id), lines:, rows:, window:, content:, code_box: code, crest_y: (page.y + 18.0 unless layout.short?),
                  actions: [reveal, *row_of(buttons_y, [[:group_history, GroupWords.history], [:group_leave, GroupWords.leave]]), back_action])
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

      def pad(rect) = CodePad.new(rect:, gap: 8.0, key_height: [button + 18, 74.0].min, erase: GroupWords.erase, submit: GroupWords.submit)
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
  end
end
