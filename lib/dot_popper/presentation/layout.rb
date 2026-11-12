# frozen_string_literal: true

module DotPopper
  module Presentation
    # A rectangle in graphics units.
    class Rect < Data.define(:x, :y, :width, :height)
      def right = x + width
      def bottom = y + height
      def center_x = x + (width / 2.0)
      def center_y = y + (height / 2.0)

      def contains?(px, py) = px.between?(x, right) && py.between?(y, bottom)

      # Whether this rectangle and +other+ share more than an edge.
      def overlaps?(other) = x < other.right && other.x < right && y < other.bottom && other.y < bottom

      # The rectangle with any of its edges moved in to +left+, +top+,
      # +right+, or +bottom+; an edge already inside stays where it is.
      def cut(left: x, top: y, right: self.right, bottom: self.bottom)
        new_x = [x, left].max
        new_y = [y, top].max
        Rect.new(x: new_x, y: new_y, width: [[self.right, right].min - new_x, 0.0].max,
                 height: [[self.bottom, bottom].min - new_y, 0.0].max)
      end

      # The rectangle grown by +amount+ on every side, or shrunk when negative.
      def inset(amount) = Rect.new(x: x + amount, y: y + amount, width: width - (2 * amount), height: height - (2 * amount))

      # The rectangle grown about its center to at least +least+ across and
      # down, as a button's hit area around its drawn shape.
      def reach(least)
        wide = [width, least].max
        tall = [height, least].max
        Rect.new(x: center_x - (wide / 2.0), y: center_y - (tall / 2.0), width: wide, height: tall)
      end
    end

    # A labeled choice between options side by side, as a segmented
    # control: where its label goes, and each option's segment, left to
    # right.
    class Segmented < Data.define(:label, :options)
      # The outline around every segment.
      def frame
        first, last = options.first, options.last
        Rect.new(x: first.x, y: first.y, width: last.right - first.x, height: first.height)
      end
    end

    # The window's first size on a desktop: a reference play area measured
    # in radii, so the field is about as crowded as on a tablet, shrunk to
    # fit +most+ of the desktop if the desktop is smaller.
    class WindowStyle < Data.define(:width, :height, :most)
      def size_for(desktop_width, desktop_height, radius)
        wanted_width = width * radius
        wanted_height = height * radius
        fit = [1.0, (desktop_width * most) / wanted_width, (desktop_height * most) / wanted_height].min
        [(wanted_width * fit).floor, (wanted_height * fit).floor]
      end

      # The window's size and its smallest, in the system's window
      # coordinates, which are +per_unit+ to a graphics unit: 1 where they
      # are points (a Mac), and the display's scale where they are pixels
      # (Windows at 200%), so the window is the same size in units, and
      # never smaller than +smallest+ units, on any display. +wanted+ is a
      # size in units asked for (DOT_POPPER_WINDOW), or nil for one fitted
      # to the desktop (+desktop_width+ by +desktop_height+, in window
      # coordinates).
      def mode_for(desktop_width, desktop_height, radius, per_unit:, smallest:, wanted: nil)
        units = wanted || size_for(desktop_width / per_unit, desktop_height / per_unit, radius)
        (units.map { [it, 0].max } + smallest).map { (it * per_unit).round }
      end
    end

    # Sizes for the screen's furniture, in graphics units at a scale of 1:
    # the space kept clear inside the safe area, the mute button, and the
    # screen size at which text is drawn at its nominal size. A screen
    # short of room shrinks its type by +step+ at a time down to +shrink+
    # of its size, and never below +least+ units, unless it was smaller.
    class LayoutStyle < Data.define(:margin, :button, :reference, :shrink, :step, :least); end

    # Where things go on a screen of a given size. The playfield is the
    # whole window; text and buttons stay inside +safe+, the part that no
    # notch, rounded corner, or home indicator covers.
    class Layout < Data.define(:width, :height, :safe, :style)

      # The scale for text and the HUD: 1 on a mid-sized window, smaller on
      # a phone, a little larger on a big screen.
      def ui = ([safe.width, safe.height].min / style.reference).clamp(0.72, 1.35)

      def scaled(size) = (size * ui).round

      # The type scales a crowded screen tries, from full size down.
      def type_scales = (0..((1 - style.shrink) / style.step).round).map { 1.0 - (it * style.step) }

      # +size+ scaled to the screen, then by +scale+, in whole units.
      def type_size(size, scale = 1.0)
        nominal = scaled(size)
        [(nominal * scale).round, [nominal, style.least].min].max
      end

      def margin = style.margin * ui

      # A short window held sideways: Back moves to the top left, beside
      # the heading, where a phone's thumb already is.
      def short? = safe.height < 520 && safe.width > safe.height
      def phone? = [safe.width, safe.height].min < 600

      # The redesigned screens' margin and button height, as the mocks draw them.
      def page_margin = phone? ? 16.0 : 24.0
      def control_height = phone? ? 56.0 : 60.0
      def heading_size = phone? ? 32 : 40
      def heading_y = short? ? safe.y + page_margin + (control_height / 2.0) : safe.y + (phone? ? 34.0 : 55.0)

      # A screen's heading for +text+: its type size and the middle of its
      # line across. It is centered, shrunk until it fits; on a short window
      # too narrow to center it clear of Back, it sits in the room right of
      # Back instead.
      def heading_place(text, measure)
        fit = lambda do |room, least|
          size = heading_size
          size -= 1 while size > least && measure.width(:bold, size, text) > room
          size if measure.width(:bold, size, text) <= room
        end
        return [fit.(safe.width - (2 * page_margin), 18) || 18, center_x] unless short?

        centred = fit.(2.0 * (center_x - back_button.right - page_margin), 24)
        return [centred, center_x] if centred

        left = back_button.right + page_margin
        right = safe.right - page_margin
        [fit.(right - left, 14) || 14, (left + right) / 2.0]
      end

      # Where a screen's content goes: under the heading, and clear of Back.
      def page
        top = short? ? back_button.bottom + page_margin : heading_y + (heading_size * 0.75)
        bottom = short? ? safe.bottom - page_margin : back_button.y - page_margin
        Rect.new(x: safe.x + page_margin, y: top, width: safe.width - (2 * page_margin), height: [bottom - top, 0.0].max)
      end
      def center_x = safe.center_x
      def center_y = safe.center_y
      def top = safe.y + margin

      # The whole window, notches and all.
      def whole = Rect.new(x: 0.0, y: 0.0, width: width.to_f, height: height.to_f)

      # The Tutorial's skip button, in the safe area's top right corner,
      # level with the HUD and clear of it, where the tutorial's dots never
      # go. It is never smaller than a fingertip (44 units).
      def skip_button
        width = control_height * 1.8
        Rect.new(x: safe.right - page_margin - width, y: safe.bottom - page_margin - control_height, width:, height: control_height)
      end

      # Back: bottom left, or top left on a short window.
      def back_button
        y = short? ? safe.y + page_margin : safe.bottom - page_margin - control_height
        Rect.new(x: safe.x + page_margin, y:, width: 120.0, height: control_height)
      end

      # The Stats screen's "Clear my stats…": bottom right, or top right on
      # a short window.
      def clear_stats_button
        width = [control_height * 3.1, safe.width - (2 * page_margin)].min
        y = short? ? safe.y + page_margin : safe.bottom - page_margin - control_height
        Rect.new(x: safe.right - page_margin - width, y:, width:, height: control_height)
      end

      # Where the screens not yet redrawn put a row's second button.
      def credits_button = Rect.new(x: back_button.right + page_margin, y: back_button.y, width: control_height * 3.0, height: control_height)
      def stats_floor(**) = [back_button.y, clear_stats_button.y].min

      # The size of a screen's main button, the title's Play and Game
      # Over's Continue, for dots of +radius+: at least a dot across, and
      # a button's height, so it is the biggest thing to press; nearly the
      # whole width of a phone, and wide enough for its word elsewhere.
      def primary_size(radius)
        height = [2.0 * radius, button_size].max
        room = safe.width - (2 * margin)
        [[room, [height * 4.5, [room * 0.9, 340.0].min].max].min, height]
      end

      # Where a press reaches a main button drawn at +rect+: a dot's width
      # at least, and a margin more on every side.
      def primary_reach(rect, radius) = rect.reach(2.0 * radius).inset(-margin)

      # Undo, once the records are cleared, at the same corner.
      def undo_button
        clear = clear_stats_button
        clear.with(x: clear.right - (clear.height * 2.4), width: clear.height * 2.4)
      end

      # Never smaller than a fingertip (44 units).
      def button_size = [style.button * ui, 44.0].max

    end
  end
end
