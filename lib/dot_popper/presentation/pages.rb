# frozen_string_literal: true

module DotPopper
  module Presentation
    # One row of Settings: its +key+, label, glyph, the +choices+ as
    # [text, chosen?, name], and where its label and its pill's parts go.
    class SettingsRow < Data.define(:key, :label, :glyph, :choices, :label_at, :frame, :rects); end

    # Settings laid out: its rows, Credits and licenses, Privacy, and how
    # tall all of it is, for a window too short to show it whole.
    class SettingsPlan < Data.define(:rows, :credits, :privacy, :server, :height)
      def initialize(rows:, credits:, privacy:, height:, server: nil) = super
    end

    # Settings: each row's name beside its choices, or above them on a
    # narrow screen, then Credits and licenses and Privacy, and under them,
    # while setdef is gone, Change Server (+server+). Where the page is too
    # short for all of it, it scrolls, +offset+ down.
    class SettingsScreen < Data.define(:layout, :rows, :offset, :server)
      def initialize(layout:, rows:, offset: 0.0, server: false) = super

      def plan
        area = layout.page
        stacked? ? stacked(area) : beside(area)
      end

      private

      def stacked? = layout.safe.width < 620
      def button = layout.control_height

      def stacked(area)
        top = area.y + 8 - offset
        y = top
        placed = rows.map do |key, label, glyph, choices|
          row = SettingsRow.new(key:, label:, glyph:, choices:, label_at: [area.x, y + 11], frame: frame = Rect.new(x: area.x, y: y + 28, width: area.width, height: button + 6), rects: rects(frame, choices))
          y += frame.height + 28 + 28
          row
        end
        y += 4
        credits = pill(area.x, y, area.width)
        privacy = pill(area.x, y + button + 10, area.width)
        changing = (pill(area.x, privacy.bottom + 10, area.width) if server)
        SettingsPlan.new(rows: placed, credits:, privacy:, server: changing, height: (changing || privacy).bottom - top + 8)
      end

      def beside(area)
        label_width = [area.width * 0.28, 226.0].min
        width = [area.width, 928.0].min
        left = layout.center_x - (width / 2.0)
        tall = button + 14
        total = (rows.size * (tall + 28)) + button + 8 + (server ? button + 12 : 0)
        y = area.y + [(area.height - total) / 2.0, 0.0].max - offset
        placed = rows.map do |key, label, glyph, choices|
          row = SettingsRow.new(key:, label:, glyph:, choices:, label_at: [left, y + (tall / 2.0)], frame: frame = Rect.new(x: left + label_width, y:, width: width - label_width, height: tall), rects: rects(frame, choices))
          y += tall + 28
          row
        end
        half = (width - 12) / 2.0
        changing = (pill(left, y + button + 12, half) if server)
        SettingsPlan.new(rows: placed, credits: pill(left, y, half), privacy: pill(left + half + 12, y, half), server: changing, height: total)
      end

      def pill(x, y, width) = Rect.new(x:, y:, width:, height: button)

      def rects(frame, choices)
        share = frame.width / choices.size
        choices.each_with_index.map { |_, i| Rect.new(x: frame.x + (i * share), y: frame.y, width: share, height: frame.height) }
      end
    end

    # A cell of the Achievements grid: its achievement's +id+, the middle
    # of its icon, the icon's radius, and the middle of its name's line.
    class AchievementCell < Data.define(:id, :x, :y, :radius, :name_y)
      def rect = Rect.new(x: x - (radius * 1.3), y: y - radius, width: radius * 2.6, height: name_y - y + radius + 12)
    end

    # The grid of achievements: as many columns as fit, a short last row
    # centered, as tall as it needs, in a window that scrolls.
    class AchievementsScreen < Data.define(:layout, :ids)
      def window = layout.page
      def radius = short? ? 36.0 : (layout.safe.width < 600 ? 44.0 : 56.0)
      def columns = [[(window.width / (radius * 3.0)).floor, 2].max, ids.size].min

      def height = (rows.size * pitch) - (pitch - cell_height)

      def cells(offset)
        top = window.y + [(window.height - height) / 2.0, 0.0].max - offset
        rows.each_with_index.flat_map do |row, r|
          row.each_with_index.map do |id, c|
            x = layout.center_x + ((c - ((row.size - 1) / 2.0)) * step)
            y = top + (r * pitch) + radius
            AchievementCell.new(id:, x:, y:, radius:, name_y: y + radius + (short? ? 16.0 : 20.0))
          end
        end
      end

      private

      def short? = layout.short?
      def rows = ids.each_slice(columns).to_a
      def step = [window.width / columns, radius * 3.4].min
      def cell_height = (radius * 2) + (short? ? 28.0 : 36.0)
      def pitch = cell_height + (short? ? 10.0 : 18.0)
    end

    # Where the achievement dialog's parts go, stacked from its top: the
    # +card+, the icon's middle and radius, the name, the status, the
    # lines of how to earn it, the progress bar's rect, and its buttons
    # (as [name, rect]) in a row.
    class AchievementDialogPlan < Data.define(:card, :icon_y, :radius, :name_y, :status_y, :lines, :line_size, :lines_y, :bar, :buttons)
      def controls = buttons
    end

    class AchievementDialog < Data.define(:layout, :measure, :how, :status, :progress, :buttons)
      def plan
        safe = layout.safe
        width = [safe.width - (2 * layout.page_margin), 520.0].min
        pad = 27.0
        radius = layout.short? ? 36.0 : 64.0
        room = width - (2 * pad)
        size = layout.short? ? 17 : 20
        lines = Words.wrap(how, room) { measure.width(:semibold, size, it) }
        line_height = measure.height(:semibold, size)
        total = pad + (2 * radius) + 12 + 38 + (status ? 26 : 0) + 6 + (lines.size * line_height) + (progress ? 56 : 16) + 60 + pad
        y = safe.y + [(safe.height - total) / 2.0, 8.0].max
        card = Rect.new(x: layout.center_x - (width / 2.0), y:, width:, height: total)
        icon_y = y + pad + radius
        name_y = icon_y + radius + 12 + 19
        status_y = name_y + 19 + 13
        lines_y = status_y + (status ? 13 : -13) + 6
        bar = (Rect.new(x: card.x + pad, y: lines_y + (lines.size * line_height) + 40, width: room, height: 11) if progress)
        AchievementDialogPlan.new(card:, icon_y:, radius:, name_y:, status_y:, lines:, line_size: size, lines_y:, bar:, buttons: row(card, pad, card.bottom - pad - 60))
      end

      private

      def row(card, pad, y)
        width = card.width - (2 * pad)
        narrow = buttons.select { |name, _| %i[prev next].include?(name) }
        wide = buttons.size - narrow.size
        narrow_width = 72.0
        share = (width - (narrow.size * (narrow_width + 8)) - ([wide - 1, 0].max * 8)) / [wide, 1].max
        x = card.x + pad
        buttons.map do |name, _text|
          each = %i[prev next].include?(name) ? narrow_width : share
          rect = Rect.new(x:, y:, width: each, height: 60.0)
          x += each + 8
          [name, rect]
        end
      end
    end

    # The Privacy screen: its lines of text, the button to the policy,
    # Delete my friend group data, and the line under it.
    class PrivacyPlan < Data.define(:left, :lines, :line_size, :policy, :delete, :note_lines, :note_y); end

    class PrivacyScreen < Data.define(:layout, :measure, :lines, :note, :deletable)
      def plan
        area = layout.page
        width = [area.width, 780.0].min
        left = layout.center_x - (width / 2.0)
        size = layout.short? ? 17 : (layout.safe.width < 600 ? 18 : 22)
        y = area.y + (layout.safe.width < 600 ? 8.0 : [(area.height - (2 * 34) - 180) / 2.0, 8.0].max)
        wrapped = lines.map do |glyph, text|
          rows = Words.wrap(text, width - 42) { measure.width(:semibold, size, it) }
          entry = [glyph, rows, y]
          y += (rows.size * (size * 1.5)) + 18
          entry
        end
        y += 16
        button = layout.control_height + (layout.safe.width < 600 ? 0.0 : 12.0)
        policy = Rect.new(x: left, y:, width:, height: button)
        delete = (Rect.new(x: left, y: policy.bottom + 16, width:, height: button) if deletable)
        note_top = (delete || policy).bottom + 20
        note_lines = deletable ? Words.wrap(note, width) { measure.width(:semibold, 15, it) } : []
        PrivacyPlan.new(left:, lines: wrapped, line_size: size, policy:, delete:, note_lines:, note_y: note_top)
      end
    end

    # Change Server: its lines of text (a sign and words each), which
    # server is in use, Paste server address, Use setdef's server while a
    # replacement is chosen, and the line saying how the last paste went.
    class ServerPlan < Data.define(:left, :width, :lines, :line_size, :now, :now_y, :paste, :reset, :status, :status_y)
      def initialize(left:, width:, lines:, line_size:, now:, now_y:, paste:, status_y:, reset: nil, status: nil) = super
    end

    # Laid out as the Privacy screen is (PrivacyScreen): one column, the
    # warning first, as the thing to know before choosing (Podmajersky:
    # write for the state the player is in), then what to do, then the
    # buttons, each naming its action.
    class ServerScreen < Data.define(:layout, :measure, :lines, :now, :status, :resettable)
      def plan
        area = layout.page
        width = [area.width, 780.0].min
        left = layout.center_x - (width / 2.0)
        narrow = layout.safe.width < 600
        size = layout.short? ? 17 : (narrow ? 18 : 22)
        y = area.y + (narrow || layout.short? ? 8.0 : [(area.height - 330) / 2.0, 8.0].max)
        wrapped = lines.map do |glyph, text|
          rows = Words.wrap(text, width - 42) { measure.width(:semibold, size, it) }
          entry = [glyph, rows, y]
          y += (rows.size * (size * 1.5)) + 18
          entry
        end
        now_y = y + 6
        button = layout.control_height + (narrow ? 0.0 : 12.0)
        paste = Rect.new(x: left, y: now_y + 24, width:, height: button)
        reset = (Rect.new(x: left, y: paste.bottom + 12, width:, height: button) if resettable)
        # A short window has no room below the buttons, so how the paste
        # went takes the place of which server is in use, which it says too.
        shown_now, shown_status = layout.short? && status ? [status, nil] : [now, status]
        ServerPlan.new(left:, width:, lines: wrapped, line_size: size, now: shown_now, now_y:, paste:, reset:, status: shown_status, status_y: (reset || paste).bottom + 24)
      end
    end
  end
end
