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

      # The rectangle grown about its centre to at least +least+ across and
      # down, as a button's hit area around its drawn shape.
      def reach(least)
        wide = [width, least].max
        tall = [height, least].max
        Rect.new(x: center_x - (wide / 2.0), y: center_y - (tall / 2.0), width: wide, height: tall)
      end
    end

    # A labelled choice between options side by side, as a segmented
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
    class WindowLook < Data.define(:width, :height, :most)
      def size_for(desktop_width, desktop_height, radius)
        wanted_width = width * radius
        wanted_height = height * radius
        fit = [1.0, (desktop_width * most) / wanted_width, (desktop_height * most) / wanted_height].min
        [(wanted_width * fit).floor, (wanted_height * fit).floor]
      end
    end

    # Sizes for the screen's furniture, in graphics units at a scale of 1:
    # the space kept clear inside the safe area, the mute button, and the
    # screen size at which text is drawn at its nominal size. A screen
    # short of room shrinks its type by +step+ at a time down to +shrink+
    # of its size, and never below +least+ units, unless it was smaller.
    class LayoutLook < Data.define(:margin, :button, :reference, :shrink, :step, :least); end

    # Where things go on a screen of a given size. The playfield is the
    # whole window; text and buttons stay inside +safe+, the part that no
    # notch, rounded corner, or home indicator covers.
    class Layout < Data.define(:width, :height, :safe, :look)
      HOW_TO_PLAY = 3.8 # "How to play"'s width, in its heights, with room
      HOW_TO_PLAY_LEAST = 3.1 # ...and the least it is drawn at in the bottom row

      # The scale for text and the HUD: 1 on a mid-sized window, smaller on
      # a phone, a little larger on a big screen.
      def ui = ([safe.width, safe.height].min / look.reference).clamp(0.72, 1.35)

      def scaled(size) = (size * ui).round

      # The type scales a crowded screen tries, from full size down.
      def type_scales = (0..((1 - look.shrink) / look.step).round).map { 1.0 - (it * look.step) }

      # +size+ scaled to the screen, then by +scale+, in whole units.
      def type_size(size, scale = 1.0)
        nominal = scaled(size)
        [(nominal * scale).round, [nominal, look.least].min].max
      end

      def margin = look.margin * ui
      def center_x = safe.center_x
      def center_y = safe.center_y
      def top = safe.y + margin

      # The whole window, notches and all.
      def whole = Rect.new(x: 0.0, y: 0.0, width: width.to_f, height: height.to_f)

      # The mute toggle, in the safe area's bottom right corner. It is
      # never smaller than a fingertip (44 units).
      def mute_button
        size = button_size
        Rect.new(x: safe.right - margin - size, y: safe.bottom - margin - size, width: size, height: size)
      end

      # The Tutorial's skip button, in the safe area's top right corner,
      # level with the HUD and clear of it, where the tutorial's dots never
      # go. It is never smaller than a fingertip (44 units).
      def skip_button
        size = button_size
        Rect.new(x: safe.right - margin - size, y: top, width: size, height: size)
      end

      # The title's "Your records" button, in the safe area's bottom left
      # corner, across from the mute button and as tall as it.
      def records_button
        height = button_size
        Rect.new(x: safe.x + margin, y: safe.bottom - margin - height, width: height * 3.8, height:)
      end

      # The title's "How to play": a quiet pill with the Tutorial's guide
      # on it, beside the mute button, as tall as it. It takes the room
      # between "Your records" and the mute button, up to HOW_TO_PLAY
      # buttons' heights across; where that is less than HOW_TO_PLAY_LEAST,
      # as on a small phone held upright, it takes a row of its own above
      # the mute button instead, as the dot-size choice does.
      def how_to_play_button
        height = button_size
        right = mute_button.x - margin
        room = right - (records_button.right + margin)
        if room >= height * HOW_TO_PLAY_LEAST
          width = [height * HOW_TO_PLAY, room].min
          return Rect.new(x: right - width, y: mute_button.y, width:, height:)
        end

        width = [height * HOW_TO_PLAY, safe.width - (2 * margin)].min
        Rect.new(x: safe.right - margin - width, y: mute_button.y - row_apart(height) - height, width:, height:)
      end

      # The Records screen's "Clear my records…": small, in the safe
      # area's bottom right corner, across from where "Your records" was
      # pressed, and on a row of its own under the prompt to go back.
      def clear_records_button
        height = button_size
        width = [height * 4.6, safe.width - (2 * margin)].min
        Rect.new(x: safe.right - margin - width, y: safe.bottom - margin - height, width:, height:)
      end

      # The Records screen's Back, in the bottom left corner, where "Your
      # records" was pressed, across from "Clear my records…" and never
      # into it.
      def back_button
        height = button_size
        room = safe.width - (3 * margin) - clear_records_button.width
        Rect.new(x: safe.x + margin, y: safe.bottom - margin - height, width: [height * 2.4, room].min, height:)
      end

      # The Records screen's Credits, a quiet pill beside Back, between it
      # and "Clear my records…", when there is room for it there; and
      # otherwise, as on an upright phone, on a row of its own above Back.
      def credits_button
        height = button_size
        wanted = height * 3.0
        room = clear_records_button.x - margin - back_button.right - margin
        if room >= wanted
          Rect.new(x: back_button.right + margin, y: back_button.y, width: wanted, height:)
        else
          Rect.new(x: back_button.x, y: back_button.y - margin - height, width: [wanted, safe.width - (2 * margin)].min, height:)
        end
      end

      # The top of the Records screen's buttons, whichever row they are on.
      def records_floor = [back_button.y, credits_button.y, clear_records_button.y].min

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
        height = button_size
        width = height * 2.4
        Rect.new(x: safe.right - margin - width, y: safe.bottom - margin - height, width:, height:)
      end

      # The title's choice of dot size: its label, then its two segments,
      # each as tall as a button and wide enough for a dot icon and a few
      # words. The title shows it only where it changes something. With
      # room between "Your records" and "How to play", it sits there,
      # label on the left, its segments centred on the screen if they can
      # be. Otherwise, as on an upright phone, its segments are centred a
      # row above the buttons, under the label.
      def sizing_control
        height = button_size
        segment = height * 4.2
        label = height * 2.1
        left = records_button.right + margin
        how = how_to_play_button
        right = (how.y == mute_button.y ? how.x : mute_button.x) - margin
        return stacked_choice(height, segment, label) if right - left < label + (segment * 2)

        x = (center_x - segment).clamp(left + label, right - (segment * 2))
        y = mute_button.y
        Segmented.new(label: Rect.new(x: x - label, y:, width: label, height:),
                      options: segments(x, y, segment, height))
      end

      # Never smaller than a fingertip (44 units).
      def button_size = [look.button * ui, 44.0].max

      private

      # How far apart two rows of buttons are, each +height+ tall, so each
      # is reached a good way past its edge: up to a standard dot's width
      # around it, as far as a short screen allows. (The Android playtest
      # found a tap on Standard's lower half opening "Your records".)
      def row_apart(height) = [margin, [(2 * Rules::RADIUS) - height, safe.height * 0.05].min].max

      # The choice a row above the buttons, and above "How to play" where
      # that has a row of its own.
      def stacked_choice(height, segment, label)
        segment = [segment, (safe.width / 2.0) - margin].min
        y = [mute_button.y, how_to_play_button.y].min - row_apart(height) - height
        tall = height * 0.7
        Segmented.new(label: Rect.new(x: center_x - (label / 2.0), y: y - tall, width: label, height: tall),
                      options: segments(center_x - segment, y, segment, height))
      end

      def segments(x, y, width, height)
        [Rect.new(x:, y:, width:, height:), Rect.new(x: x + width, y:, width:, height:)]
      end
    end
  end
end
