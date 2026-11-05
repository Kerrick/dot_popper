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
    # screen size at which text is drawn at its nominal size.
    class LayoutLook < Data.define(:margin, :button, :reference); end

    # Where things go on a screen of a given size. The playfield is the
    # whole window; text and buttons stay inside +safe+, the part that no
    # notch, rounded corner, or home indicator covers.
    class Layout < Data.define(:width, :height, :safe, :look)
      # The scale for text and the HUD: 1 on a mid-sized window, smaller on
      # a phone, a little larger on a big screen.
      def ui = ([safe.width, safe.height].min / look.reference).clamp(0.72, 1.35)

      def scaled(size) = (size * ui).round

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

      # The title's Daily button, in the safe area's bottom left corner,
      # placed so its hit area, at least +least+ across and down, is
      # inside the safe area too.
      def daily_button(least)
        height = button_size
        width = height * 4.6
        middle = safe.bottom - margin - ([height, least].max / 2.0)
        left = safe.x + margin + (([width, least].max - width) / 2.0)
        Rect.new(x: left, y: middle - (height / 2.0), width:, height:)
      end

      # Game Over's Share button, under the round's summary.
      def share_button
        height = button_size
        width = height * 4.6
        Rect.new(x: center_x - (width / 2.0), y: center_y + (safe.height * 0.3) - (height / 2.0), width:, height:)
      end

      # Where Game Over's prompt goes: lower when a Share button is up.
      def continue_y(share) = center_y + (safe.height * (share ? 0.41 : 0.28))

      private

      # Never smaller than a fingertip (44 units).
      def button_size = [look.button * ui, 44.0].max
    end
  end
end
