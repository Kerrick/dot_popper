# frozen_string_literal: true

module DotPopper
  module Presentation
    # The player's inputs, as the shell hands them to the InputHandler: in
    # the game's own names (Shell::LotaInput turns the engine's into
    # these), and as they happened, before anything decides what they
    # mean.

    # A key pressed on a keyboard: +key+, as the game names it
    # (Shell::LotaInput#key), or nil for a key the game doesn't name; and
    # +held+, the modifier keys held with it: +:ctrl+, +:alt+, and
    # +:command+ (Cmd on a Mac, the Windows or Super key elsewhere).
    class KeyPress < Data.define(:key, :held)
      def initialize(key:, held: []) = super(key:, held: held.freeze)

      # Whether any of +modifiers+ is held.
      def held?(*modifiers) = modifiers.any? { held.include?(it) }
    end

    # A gamepad's button went down or came up: +button+ as the game names
    # it (GamepadButtons), or nil for one it doesn't.
    class ButtonPress < Data.define(:button); end
    class ButtonRelease < Data.define(:button); end

    # A gamepad's trigger, +:left+ or +:right+, read +value+, from 0 (let
    # go) to 1.
    class TriggerPull < Data.define(:trigger, :value); end

    # A gamepad was unplugged, so whatever it held is let go.
    class GamepadRemoved < Data.define; end

    # A mouse button, +button+ (+:left+, +:right+, +:middle+, or a side
    # button's +:side4+ and up), went down or came up at +x+, +y+; and the
    # mouse moved there. +made_up+ is true where the system made it up for
    # a finger (SDL's istouch).
    class MousePress < Data.define(:x, :y, :button, :made_up); end
    class MouseRelease < Data.define(:x, :y, :button, :made_up); end
    class MouseMove < Data.define(:x, :y, :made_up); end

    # A finger, +id+, went down, moved, or lifted at +x+, +y+. +screen+ is
    # whether a touchscreen's, not a trackpad's (whose places run from 0
    # to 1), and +made_up+ whether the system made it up from the mouse.
    class TouchPress < Data.define(:id, :x, :y, :screen, :made_up); end
    class TouchMove < Data.define(:id, :x, :y, :screen, :made_up); end
    class TouchRelease < Data.define(:id, :x, :y, :screen, :made_up); end

    # The mouse wheel turned +notches+, up when positive.
    class WheelTurn < Data.define(:notches); end

    # The window lost focus, so a release may never come.
    class FocusLost < Data.define; end

    # The mouse left the window.
    class MouseLeft < Data.define; end
  end
end
