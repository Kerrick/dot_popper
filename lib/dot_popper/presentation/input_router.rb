# frozen_string_literal: true

module DotPopper
  module Presentation
    # A press the game should hear: where, and the InputKind that made
    # it.
    class Tap < Data.define(:x, :y, :kind); end

    # Decides which presses are taps. A tap counts when the button or
    # finger goes down, and every finger is a tap of its own. A gamepad's
    # press is a click where its cursor is. Moves and releases are sorted
    # the same way, for dragging the game-over pile. Each Tap says what
    # made it, so the words can follow the player's hand (Show#input=).
    # What the engine reports that is no press of the player's own (the
    # mouse press SDL makes up for a finger, a trackpad's touches) the
    # shell leaves out before it asks (Shell::LotaInput).
    class InputRouter < Data.define
      # The tap for a mouse button that counts going down at +x+, +y+
      # (which buttons count is the shell's: Shell::LotaInput).
      def mouse_pressed(x, y) = Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::MOUSE)

      # The tap for finger +id+ going down at +x+, +y+, or nil where it has
      # no position.
      def touch_pressed(_id, x, y)
        return unless x.is_a?(Numeric) && y.is_a?(Numeric)

        Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::TOUCH)
      end

      # Where the mouse moved or let go, as a Tap.
      def mouse_moved(x, y) = Tap.new(x: x.to_f, y: y.to_f, kind: InputKind::MOUSE)
      def mouse_released(x, y) = mouse_pressed(x, y)

      # Where a finger moved or lifted, as a Tap, or nil, as for its press.
      def touch_moved(id, x, y) = touch_pressed(id, x, y)
      def touch_released(id, x, y) = touch_pressed(id, x, y)

      # The tap for a gamepad's press at +cursor+ (GamepadCursor): a
      # click there. Its release is at the cursor too, wherever it has
      # moved since.
      def gamepad_pressed(cursor) = Tap.new(x: cursor.x.to_f, y: cursor.y.to_f, kind: InputKind::GAMEPAD)
      def gamepad_released(cursor) = gamepad_pressed(cursor)
    end
  end
end
