# frozen_string_literal: true

module DotPopper
  module Presentation
    # What the player last played with: a finger, a mouse, or a gamepad.
    # The words that say what to do follow it (Words#for), so they name
    # the press the player is making: a tap, a click, or a button.
    class InputKind < Data.define(:name)
      TOUCH = new(name: :touch)
      MOUSE = new(name: :mouse)
      GAMEPAD = new(name: :gamepad)

      # What a player is assumed to hold before they press anything: a
      # finger on a phone or tablet, a mouse on a computer.
      def self.starting(touch:) = touch ? TOUCH : MOUSE
    end

    # Something said one way for each kind of input.
    class ByInput < Data.define(:touch, :mouse, :gamepad)
      # The one for +kind+ (InputKind).
      def for(kind) = public_send(kind.name)
    end
  end
end
