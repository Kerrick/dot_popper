# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the Friend group screen, in graphics units at a scale of
    # 1: its heading's and its text's type, the widest its column gets,
    # and how dark the title's dots go behind it.
    class GroupLook < Data.define(:heading, :text, :column, :veil); end

    # How a Mark (Groups::Mark) is drawn: a dot of one colour with one
    # dark shape on it. The colours are far apart in lightness as well as
    # in hue, and each has a shape of its own, so no two look alike to a
    # player who cannot tell colours apart, or in grayscale.
    class MarkLook < Data.define(:color, :shape); end

    # A line of words where the screen puts it: +kind+ is :text, :note or
    # :alert, and says how it reads.
    class GroupLine < Data.define(:text, :y, :kind); end

    # A button the screen offers: +name+ is what Show#tap hears. A dot to
    # pick has no text, and a digit's is the digit.
    class GroupAction < Data.define(:name, :rect, :text); end

    # A member's row: where it is, the mark they wear, whether it holds
    # the trophy, and whether it is this player.
    class GroupRow < Data.define(:rect, :mark, :holder, :me); end

    # Where the Friend group screen's parts go: +size+ its text's type,
    # the heading's middle +heading_y+ and its +heading_size+, its lines
    # (GroupLine), the box that shows the code tapped so far (a Rect, or
    # nil), its buttons (GroupAction), and its member rows.
    class GroupPlan < Data.define(:size, :heading_y, :heading_size, :lines, :code_box, :actions, :rows)
      def controls = actions.map { [it.name, it.rect] }
    end

    # The Friend group screen laid out in the safe area, from the
    # GroupPanel's state: the door (a dot to wear, a code tapped on its
    # digits, Join and Create) for someone in no group, or the group itself
    # (the trophy and its members, in as many columns as they need to
    # fit). Every button is a thumb's height, and Leave and Delete sit
    # where nobody presses them by accident. Nothing on it is typed.
    class GroupScreen < Data.define(:layout, :look, :measure, :panel, :standard_dots, :back_text)
      ROW = 1.1 # a member's row's height, in button heights
      DIGITS = %w[1 2 3 4 5 6 7 8 9 0].freeze
      MARK_LEAST = 36.0 # the least a dot to pick is across before they go in two rows

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

      # The lines of +text+, wrapped to +room+, from +y+ down.
      def wrapped(text, y, kind, room = column_width)
        Words.balance(text, room) { measure.width(:semibold, size, it) }
             .each_with_index.map { |line, i| GroupLine.new(text: line, y: y + (line_height * i), kind:) }
      end

      def heading_y = layout.top + (heading_size * 0.5)

      def common_actions
        back = GroupAction.new(name: :back, rect: layout.back_button, text: back_text)
        panel.groups.known? ? [back, GroupAction.new(name: :group_delete, rect: layout.clear_records_button, text: GroupWords.delete)] : [back]
      end

      def alert_text = panel.note || (panel.groups.error && GroupWords.error(panel.groups.error))

      # The door: what groups are, the dot to wear, the code, and Join and
      # Create. In a window too short for one column the digits go in a
      # second, beside the first.
      def door_plan
        one = door(wide: false)
        return one if one.actions.all? { it.rect.bottom <= floor } && one.lines.all? { it.y <= floor }

        door(wide: true)
      end

      def door(wide:)
        span = wide ? [layout.safe.width - (2 * margin), 2 * look.column * layout.ui].min : column_width
        room = wide ? (span - margin) / 2.0 : span
        x0 = layout.center_x - (span / 2.0)
        x1 = wide ? x0 + room + margin : x0
        blurb = wrapped(GroupWords.blurb, under_heading, :text, span)
        top = blurb.last.y + line_height
        label = GroupLine.new(text: GroupWords.mark_label, y: top, kind: :note)
        marks = mark_buttons(x0, top + (line_height * 0.8), room)
        box, digits = code_pad(x1, wide ? marks.first.rect.y : marks.map { it.rect.bottom }.max + margin, room, wide)
        join, create = join_buttons(x0, wide ? marks.map { it.rect.bottom }.max + margin : digits.map { it.rect.bottom }.max + margin, room)
        below = [join.rect.bottom, *digits.map { it.rect.bottom }].max + (margin * 0.5)
        alert = alert_text ? wrapped(alert_text, below + (size * 0.5), :alert, span) : []
        GroupPlan.new(size:, heading_y:, heading_size:, lines: blurb + [label] + alert, code_box: box,
                      actions: [*marks, *digits, join, create, *common_actions], rows: [])
      end

      # The eight dots to wear, in a row, or in two where a row would make
      # them too small to press.
      def mark_buttons(x, y, room)
        count = Groups::Mark::COUNT
        gap = margin * 0.5
        per_row = count
        side = [button, (room - (gap * (per_row - 1))) / per_row].min
        if side < MARK_LEAST
          per_row = count / 2
          side = [button, (room - (gap * (per_row - 1))) / per_row].min
        end
        used = (side * per_row) + (gap * (per_row - 1))
        start = x + ((room - used) / 2.0)
        Array.new(count) do |i|
          rect = Rect.new(x: start + ((side + gap) * (i % per_row)), y: y + ((side + gap) * (i / per_row)), width: side, height: side)
          GroupAction.new(name: [:group_mark, i], rect:, text: nil)
        end
      end

      # Join and Create side by side.
      def join_buttons(x, y, room)
        gap = margin
        half = (room - gap) / 2.0
        join = Rect.new(x:, y:, width: half, height: button)
        [GroupAction.new(name: :group_join, rect: join, text: GroupWords.join),
         GroupAction.new(name: :group_create, rect: join.with(x: join.right + gap), text: GroupWords.create(panel.paid?))]
      end

      # The code tapped so far and the digits to tap it with: the box and
      # an erase key in a row, then the digits in as many rows as the room
      # asks (two rows of five, or three of four).
      def code_pad(x, y, room, wide)
        gap = margin * 0.5
        erase_width = button * 1.8
        box = Rect.new(x:, y:, width: room - erase_width - gap, height: button)
        erase = GroupAction.new(name: :group_erase, rect: Rect.new(x: box.right + gap, y:, width: erase_width, height: button),
                                text: GroupWords.erase)
        columns = wide ? 4 : 5
        key = (room - (gap * (columns - 1))) / columns
        keys = DIGITS.map.with_index do |digit, i|
          rect = Rect.new(x: x + ((key + gap) * (i % columns)), y: box.bottom + gap + ((button + gap) * (i / columns)), width: key, height: button)
          GroupAction.new(name: [:group_digit, digit], rect:, text: digit)
        end
        [box, [*keys, erase]]
      end

      # The group: the trophy, its members, Leave and Delete.
      def group_plan
        group = panel.groups.group
        y = under_heading
        lines = wrapped(GroupWords.trophy_line(group["trophy"]), y, :text)
        lines += wrapped(GroupWords.code_line(group["code"]), lines.last.y + line_height, :text) if group["code"]
        extra = alert_text || (GroupWords.standard_note if standard_dots)
        lines += wrapped(extra, lines.last.y + line_height, alert_text ? :alert : :note) if extra
        rows = member_rows(group["members"], lines.last.y + (line_height * 0.8))
        leave = GroupAction.new(name: :group_leave, rect: layout.credits_button, text: GroupWords.leave)
        GroupPlan.new(size:, heading_y:, heading_size:, lines:, code_box: nil,
                      actions: [leave, *common_actions], rows:)
      end

      # The members, in columns of as many rows as fit between +top+ and
      # the floor.
      def member_rows(members, top)
        row_height = button * ROW
        room = floor - (size * 0.4) - top
        per_column = [(room / row_height).floor, 1].max
        columns = (members.size.to_f / per_column).ceil.clamp(1, 2)
        width = columns == 1 ? column_width : (layout.safe.width - (3 * margin)) / 2.0
        x_of = ->(i) { columns == 1 ? left : layout.safe.x + margin + ((width + margin) * i) }
        members.each_with_index.map do |member, i|
          rect = Rect.new(x: x_of[i / per_column], y: top + ((i % per_column) * row_height), width:, height: button)
          GroupRow.new(rect:, mark: member["mark"], holder: member["holder"], me: member["me"])
        end
      end
    end
  end
end
