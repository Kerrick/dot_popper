# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the Friend group screen, in graphics units at a scale of
    # 1: its heading's and its text's type, the widest its column gets,
    # and how dark the title's dots go behind it.
    class GroupLook < Data.define(:heading, :text, :column, :veil); end

    # A line of words where the screen puts it: +kind+ is :text, :note or
    # :alert, and says how it reads.
    class GroupLine < Data.define(:text, :y, :kind); end

    # A button the screen offers: +name+ is what Show#tap hears.
    class GroupAction < Data.define(:name, :rect, :text); end

    # A member's row: where it is, the name to show, whether it holds the
    # trophy, and the row's buttons.
    class GroupRow < Data.define(:rect, :name, :holder, :actions); end

    # Where the Friend group screen's parts go: +size+ its text's type,
    # the heading's middle +heading_y+ and its +heading_size+, its lines
    # (GroupLine), its typing fields as {name: Rect, code: Rect}, its
    # buttons (GroupAction), and its member rows.
    class GroupPlan < Data.define(:size, :heading_y, :heading_size, :lines, :fields, :actions, :rows)
      def controls
        fields.map { |name, rect| [:"group_#{name}", rect] } +
          (actions + rows.flat_map(&:actions)).map { [it.name, it.rect] }
      end
    end

    # The Friend group screen laid out in the safe area, from the
    # GroupPanel's state: the door (a name, a code, Join and Create) for
    # someone in no group, or the group itself (the trophy, the invite
    # code, and its members, in as many columns as they need to fit).
    # Every button is a thumb's height, and Report, Block and Leave sit
    # where nobody presses them by accident.
    class GroupScreen < Data.define(:layout, :look, :measure, :panel, :standard_dots, :back_text)
      ROW = 1.1 # a member's row's height, in button heights

      # The title's way in, in its top left corner, level with where the
      # window buttons go on a tiny window: a pill a button high.
      def self.button(layout, labelled:)
        height = layout.button_size
        Rect.new(x: layout.safe.x + layout.margin, y: layout.top, width: labelled ? height * 2.6 : height, height:)
      end

      def plan
        panel.member? ? group_plan : door_plan
      end

      private

      def size = layout.scaled(look.text)
      def heading_size = layout.scaled(look.heading)
      def button = layout.button_size
      def margin = layout.margin
      def column_width = [look.column * layout.ui, layout.safe.width - (2 * margin)].min
      def left = layout.center_x - (column_width / 2.0)
      def line_height = size * 1.35
      def under_heading = layout.top + (heading_size * 1.3) + (size * 0.5)
      def floor = layout.records_floor - (margin * 0.5)

      # The lines of +text+, wrapped to the column, from +y+ down.
      def wrapped(text, y, kind)
        Words.balance(text, column_width) { measure.width(:semibold, size, it) }
             .each_with_index.map { |line, i| GroupLine.new(text: line, y: y + (line_height * i), kind:) }
      end

      def heading_y = layout.top + (heading_size * 0.5)

      def common_actions
        back = GroupAction.new(name: :back, rect: layout.back_button, text: back_text)
        panel.groups.known? ? [back, GroupAction.new(name: :group_delete, rect: layout.clear_records_button, text: GroupWords.delete)] : [back]
      end

      def bottom_note(y)
        return [] unless y

        wrapped(GroupWords.privacy, y, :note)
      end

      def alert_lines(y)
        text = panel.note || (panel.groups.error && GroupWords.error(panel.groups.error))
        text ? wrapped(text, y, :alert) : []
      end

      # The door: what groups are, a name, a code, Join and Create, and
      # under them what joining shares.
      def door_plan
        blurb = wrapped(GroupWords.blurb, under_heading, :text)
        top = blurb.last.y + line_height
        name = Rect.new(x: left, y: top, width: column_width, height: button)
        code = name.with(y: name.bottom + margin)
        gap = margin
        half = (column_width - gap) / 2.0
        join = Rect.new(x: left, y: code.bottom + margin, width: half, height: button)
        create = join.with(x: join.right + gap)
        actions = [GroupAction.new(name: :group_join, rect: join, text: GroupWords.join),
                   GroupAction.new(name: :group_create, rect: create, text: GroupWords.create(panel.paid?)),
                   *common_actions]
        alert = alert_lines(join.bottom + (margin * 1.5))
        note = bottom_note(alert.empty? ? join.bottom + (margin * 1.5) : nil)
        GroupPlan.new(size:, heading_y:, heading_size:, lines: blurb + alert + note,
                      fields: { name:, code: }, actions:, rows: [])
      end

      # The group: the trophy, the code, its members, Leave and Delete.
      def group_plan
        group = panel.groups.group
        y = under_heading
        lines = wrapped(GroupWords.trophy_line(group["trophy"]), y, :text)
        lines += [GroupLine.new(text: GroupWords.code_line(group["code"]), y: lines.last.y + line_height, kind: :note)]
        extra = panel.note || (panel.groups.error && GroupWords.error(panel.groups.error)) ||
                (GroupWords.standard_note if standard_dots)
        lines += wrapped(extra, lines.last.y + line_height, panel.note || panel.groups.error ? :alert : :note) if extra
        rows = member_rows(group["members"], lines.last.y + (line_height * 0.8))
        contact = GroupLine.new(text: GroupWords.contact, y: floor - (size * 0.6), kind: :note)
        leave = GroupAction.new(name: :group_leave, rect: layout.credits_button, text: GroupWords.leave)
        GroupPlan.new(size:, heading_y:, heading_size:, lines: lines + [contact], fields: {},
                      actions: [leave, *common_actions], rows:)
      end

      # The members, in columns of as many rows as fit between +top+ and
      # the contact line. A column never gets narrower than a name and
      # its two buttons.
      def member_rows(members, top)
        row_height = button * ROW
        room = floor - (size * 1.4) - top
        per_column = [(room / row_height).floor, 1].max
        columns = (members.size.to_f / per_column).ceil.clamp(1, 2)
        width = columns == 1 ? column_width : (layout.safe.width - (3 * margin)) / 2.0
        x_of = ->(i) { columns == 1 ? left : layout.safe.x + margin + ((width + margin) * i) }
        members.each_with_index.map do |member, i|
          rect = Rect.new(x: x_of[i / per_column], y: top + ((i % per_column) * row_height), width:, height: button)
          GroupRow.new(rect:, name: member["name"], holder: member["holder"], actions: row_actions(member, rect))
        end
      end

      def row_actions(member, rect)
        return [] if member["me"]

        y = rect.y
        return [row_button([:group_unblock, member["id"]], GroupWords.unblock, rect.right - (button * 2.4), y, 2.4)] if member["blocked"]

        [row_button([:group_report, member["id"]], GroupWords.report, rect.right - (button * 4.2), y, 2.2),
         row_button([:group_block, member["id"]], GroupWords.block, rect.right - (button * 1.9), y, 1.9)]
      end

      def row_button(name, text, x, y, widths)
        GroupAction.new(name:, rect: Rect.new(x:, y:, width: button * widths, height: button), text:)
      end
    end
  end
end
