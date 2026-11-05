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

      # The mute toggle, in the safe area's bottom right corner. It is
      # never smaller than a fingertip (44 units).
      def mute_button
        size = [look.button * ui, 44.0].max
        Rect.new(x: safe.right - margin - size, y: safe.bottom - margin - size, width: size, height: size)
      end
    end
  end
end
