# frozen_string_literal: true

module DotPopper
  module Presentation
    # A press the game should hear: where, and whether a finger made it.
    class Tap < Data.define(:x, :y, :touch); end

    # Decides which of Lota's input callbacks are taps. A finger on a
    # touchscreen fires touchpressed, and SDL then also makes up a
    # mousepressed for it with istouch true; only the touch counts, so one
    # finger is one tap. A trackpad's touches have normalized 0 to 1
    # coordinates and are not taps either. A tap counts when the button or
    # finger goes down, and every finger is a tap of its own. A gamepad's
    # press is a click where its cursor is.
    class InputRouter < Data.define
      MOUSE_BUTTONS = [1, 2, 3].freeze

      # The tap for a mousepressed, or nil.
      def mouse_pressed(x, y, button, istouch)
        return if istouch || !MOUSE_BUTTONS.include?(button)

        Tap.new(x: x.to_f, y: y.to_f, touch: false)
      end

      # The tap for a touchpressed, or nil.
      def touch_pressed(_id, x, y, devicetype, mouse)
        return unless devicetype.to_s == "touchscreen"
        return if mouse == true
        return unless x.is_a?(Numeric) && y.is_a?(Numeric)

        Tap.new(x: x.to_f, y: y.to_f, touch: true)
      end

      # The tap for a gamepad's press at +cursor+ (GamepadCursor): a
      # click there.
      def gamepad_pressed(cursor) = Tap.new(x: cursor.x.to_f, y: cursor.y.to_f, touch: false)
    end
  end
end
