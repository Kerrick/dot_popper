# frozen_string_literal: true

module DotPopper
  module Presentation
    # A press the game should hear: where, and the InputKind that made
    # it.
    class Tap < Data.define(:x, :y, :kind); end

    # Decides which of Lota's input callbacks are taps. A finger on a
    # touchscreen fires touchpressed, and SDL then also makes up a
    # mousepressed for it with istouch true; only the touch counts, so one
    # finger is one tap. A trackpad's touches have normalized 0 to 1
    # coordinates and are not taps either. A tap counts when the button or
    # finger goes down, and every finger is a tap of its own. A gamepad's
    # press is a click where its cursor is. Moves and releases are sorted
    # the same way, for dragging the game-over pile. Each Tap says what
    # made it, so the words can follow the player's hand (Show#input=).
    class InputRouter < Data.define
      MOUSE_BUTTONS = [1, 2, 3].freeze

      # The tap for a mousepressed, or nil.
      def mouse_pressed(x, y, button, istouch)
        return if istouch || !MOUSE_BUTTONS.include?(button)

        Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::MOUSE)
      end

      # The tap for a touchpressed, or nil.
      def touch_pressed(_id, x, y, devicetype, mouse)
        return unless devicetype.to_s == "touchscreen"
        return if mouse == true
        return unless x.is_a?(Numeric) && y.is_a?(Numeric)

        Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::TOUCH)
      end

      # Where a mouse moved or let go, as a Tap, or nil for the mouse SDL
      # makes up for a finger, or a button that is no tap's.
      def mouse_moved(x, y, istouch) = (Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::MOUSE) unless istouch)
      def mouse_released(x, y, button, istouch) = mouse_pressed(x, y, button, istouch)

      # Where a finger moved or lifted, as a Tap, or nil, as for its press.
      def touch_moved(id, x, y, devicetype, mouse) = touch_pressed(id, x, y, devicetype, mouse)
      def touch_released(id, x, y, devicetype, mouse) = touch_pressed(id, x, y, devicetype, mouse)

      # The tap for a gamepad's press at +cursor+ (GamepadCursor): a
      # click there. Its release is at the cursor too, wherever it has
      # moved since.
      def gamepad_pressed(cursor) = Tap.new(x: cursor.x.to_f, y: cursor.y.to_f, kind: InputKind::GAMEPAD)
      def gamepad_released(cursor) = gamepad_pressed(cursor)
    end
  end
end
