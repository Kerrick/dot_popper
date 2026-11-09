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
    class GroupStandingRow < Data.define(:rect, :group_id, :number, :score, :champion, :me); end

    # An entry in a group's history: the new champion and, if any, who they
    # took it from, drawn as icons so it can be read without words.
    class GroupHistoryRow < Data.define(:rect, :group_id, :change); end

    # Where a friend groups' screen's parts go: its text's +size+, the
    # heading (+heading+ its words, +heading_y+ its middle, +heading_size+
    # its type), its lines (GroupLine), the box showing the code tapped so
    # far (a Rect, or nil), its buttons (GroupAction, CodeKey), and its
    # rows.
    class GroupPlan < Data.define(:size, :heading, :heading_x, :heading_y, :heading_size, :lines, :code_box, :actions, :rows)
      def controls = actions.map { [it.name, it.rect] }
    end

    # The friend groups' screens laid out in the safe area: the list of
    # the player's groups, a group's standings, its history of the title,
    # and the keypad that joins one. Rows that outgrow a page go in pages,
    # never a scroll, so they work by a tap alone. Every button is a
    # thumb's height, and Leave and Delete sit where nobody presses them by
    # accident. Nothing on it is typed.
    class GroupScreen < Data.define(:layout, :style, :measure, :panel, :standard_dots, :back_text)
      ROW = 1.1 # a row's height, in button heights
      TALL = 520.0 # the safe height, in points, a keypad column needs

      # The title's way in, in its top left corner, level with where the
      # window buttons go on a tiny window: a pill a button high.
      def self.button(layout, labelled:)
        height = layout.button_size
        Rect.new(x: layout.safe.x + layout.margin, y: layout.top, width: labelled ? height * 2.8 : height, height:)
      end

      def plan
        case panel.page
        when :group then group_plan
        when :history then history_plan
        when :join then join_plan
        else list_plan
        end
      end

      private

      def size = layout.scaled(style.text)
      def heading_size = layout.scaled(style.heading)
      def button = layout.button_size
      def margin = layout.margin
      def gap = margin * 0.5
      def column_width = [style.column * layout.ui, layout.safe.width - (2 * margin)].min
      def left = layout.center_x - (column_width / 2.0)
      def line_height = size * 1.35
      def heading_y = layout.top + (heading_size * 0.5)
      def under_heading = layout.top + (heading_size * 1.3) + (size * 0.5)
      def floor = layout.stats_floor - (margin * 0.5)
      def short? = layout.safe.height < TALL && layout.safe.width > layout.safe.height

      def back_action = GroupAction.new(name: :back, rect: layout.back_button, text: back_text)
      def alert_text = panel.note || (panel.groups.error && GroupWords.error(panel.groups.error))

      def wrapped(text, y, kind, room = column_width)
        Words.balance(text, room) { measure.width(:semibold, size, it) }
             .each_with_index.map { |line, i| GroupLine.new(text: line, y: y + (line_height * i), kind:) }
      end

      def plan_with(heading:, lines:, actions:, rows: [], code_box: nil, heading_x: layout.center_x)
        GroupPlan.new(size:, heading:, heading_x:, heading_y:, heading_size:, lines:, code_box:, actions:, rows:)
      end

      # A row of equal pills across the column, at +y+.
      def row_of(y, actions)
        each = (column_width - (gap * (actions.size - 1))) / actions.size
        actions.each_with_index.map { |(name, text), i| GroupAction.new(name:, text:, rect: Rect.new(x: left + ((each + gap) * i), y:, width: each, height: button)) }
      end

      # Rows from +top+ to +bottom+: in as many as two columns where they
      # are too many for one, in pages beyond that. Answers the rows each
      # placed by the block, how many fit on a page, and the page's
      # controls.
      def paged(items, top, bottom, gallery: false)
        row_height = button * ROW
        per_column = [((bottom - top) / row_height).floor, 1].max
        two = !gallery && items.size > per_column && layout.safe.width > 2 * style.column * layout.ui * 0.7
        columns = two ? 2 : 1
        per_page = per_column * columns
        width = two ? (layout.safe.width - (3 * margin)) / 2.0 : column_width
        x_of = ->(i) { two ? layout.safe.x + margin + ((width + margin) * i) : left }
        panel.clamp_offset([(items.size - 1) / per_page, 0].max)
        shown = items.drop(panel.offset * per_page).first(per_page)
        placed = shown.each_with_index.map do |item, i|
          yield item, Rect.new(x: x_of[i / per_column], y: top + ((i % per_column) * row_height), width:, height: button)
        end
        [placed, per_page]
      end

      def pager(items, per_page, y)
        return [] if items.size <= per_page

        row_of(y, [[:group_older, GroupWords.older], [:group_newer, GroupWords.newer]].reject do |name, _|
          name == :group_newer ? panel.offset.zero? : panel.offset >= (items.size - 1) / per_page
        end)
      end

      def list_plan
        groups = panel.groups.groups
        lines = groups.empty? ? wrapped(GroupWords.blurb, under_heading, :text) : []
        lines += wrapped(GroupWords.privacy, lines.last.y + line_height, :note) if groups.empty?
        action_y = floor - button
        top = (lines.last&.y || under_heading - line_height) + line_height
        alert = alert_text ? wrapped(alert_text, action_y - line_height, :alert) : []
        bottom = (alert.first&.y || action_y) - margin
        make = ->(group, rect) { GroupListRow.new(rect:, group:) }
        rows, per_page = paged(groups, top, bottom, &make)
        if groups.size > per_page
          bottom -= button + gap
          rows, per_page = paged(groups, top, bottom, &make)
        end
        list_actions = rows.map { GroupAction.new(name: [:group_show, it.group.id], rect: it.rect, text: nil) }
        controls = pager(groups, per_page, bottom - button)
        plan_with(heading: GroupWords.heading, lines: lines + alert, rows:,
                  actions: [*list_actions, *row_of(action_y, [[:group_join_open, GroupWords.join(panel.pro?)], [:group_create, GroupWords.create(panel.pro?)]]),
                            *controls, back_action, *delete_action])
      end

      def delete_action
        return [] unless panel.groups.known?

        [GroupAction.new(name: :group_delete, rect: layout.clear_stats_button, text: GroupWords.delete)]
      end

      def group_plan
        group = panel.group or return list_plan
        lines = wrapped(GroupWords.title_line(group), under_heading, :text)
        lines += wrapped(GroupWords.code_line(group.join_code), lines.last.y + line_height, :note)
        extra = alert_text || (GroupWords.standard_note if standard_dots)
        lines += wrapped(extra, lines.last.y + line_height, alert_text ? :alert : :note) if extra
        top = lines.last.y + (line_height * 0.8)
        rows, = paged(group.standings, top, floor) do |member, rect|
          GroupStandingRow.new(rect:, group_id: group.id, number: member.number, score: member.top_score,
                               champion: member.number == group.champion_number, me: member.number == group.you)
        end
        plan_with(heading: GroupWords.group_heading, lines:, rows:,
                  actions: [back_action, GroupAction.new(name: :group_leave, rect: layout.credits_button, text: GroupWords.leave),
                            GroupAction.new(name: :group_history, rect: layout.clear_stats_button, text: GroupWords.history)])
      end

      def history_plan
        group = panel.group or return list_plan
        changes = panel.groups.title_changes(group.id).to_a
        lines = changes.empty? ? wrapped(GroupWords.no_history, under_heading, :note) : []
        bottom = floor - button - margin
        top = lines.last ? lines.last.y + line_height : under_heading
        rows, per_page = paged(changes, top, bottom, gallery: !short?) { |change, rect| GroupHistoryRow.new(rect:, group_id: group.id, change:) }
        plan_with(heading: GroupWords.history_heading, lines:, rows:,
                  actions: [*pager(changes, per_page, floor - button), back_action])
      end

      def pad(rect) = CodePad.new(rect:, gap:, key_height: button, erase: GroupWords.erase, submit: GroupWords.submit)
      def pad_height(room) = [CodePad.height(button, gap), room].min

      def join_plan = short? ? join_beside : join_stacked

      def code_text = CodeText.of(panel.code, GroupWords::CODE_LENGTH)

      def join_stacked
        box = Rect.new(x: left, y: under_heading, width: column_width, height: button)
        message = alert_text ? wrapped(alert_text, box.bottom + (size * 0.9), :alert) : []
        top = box.bottom + (line_height * 1.5)
        keys = pad(Rect.new(x: left, y: top, width: column_width, height: pad_height(layout.stats_floor - margin - top))).keys
        plan_with(heading: GroupWords.join_heading, lines: message, code_box: box, actions: [*keys, back_action])
      end

      def join_beside
        each = [(layout.safe.width - (3 * margin)) / 2.0, column_width].min
        x = layout.center_x - (((2 * each) + margin) / 2.0)
        box = Rect.new(x:, y: under_heading, width: each, height: button)
        message = alert_text ? wrapped(alert_text, box.bottom + (size * 0.9), :alert, each) : []
        room = layout.stats_floor - margin - layout.top
        keys = pad(Rect.new(x: x + each + margin, y: layout.top, width: each, height: pad_height(room))).keys
        plan_with(heading: GroupWords.join_heading, heading_x: box.center_x, lines: message, code_box: box, actions: [*keys, back_action])
      end
    end
  end
end
