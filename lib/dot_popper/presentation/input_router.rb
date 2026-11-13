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
    # What the engine reports that is no press of the player's own is
    # left out (#tap): the mouse press SDL makes up for a finger, a
    # mouse's side buttons, a trackpad's touches, and a touch made up
    # from the mouse.
    class InputRouter < Data.define
      # The mouse buttons that press: the left, the right and the middle.
      # A mouse's side buttons do not.
      MOUSE_BUTTONS = %i[left right middle].freeze

      # The Tap for a mouse or finger event (input_events.rb), or nil for
      # one that is no press of the player's own.
      def tap(event)
        case event
        in MousePress | MouseRelease if !event.made_up && MOUSE_BUTTONS.include?(event.button) then mouse_pressed(event.x, event.y)
        in MouseMove if !event.made_up then mouse_moved(event.x, event.y)
        in TouchPress | TouchMove | TouchRelease if event.screen && !event.made_up then touch_pressed(event.id, event.x, event.y)
        else nil
        end
      end

      # The tap for a mouse button that counts going down at +x+, +y+.
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
