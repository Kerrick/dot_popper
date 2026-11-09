# frozen_string_literal: true

module DotPopper
  module Presentation
    # What each gamepad button asks for, by the names LÖVE gives an Xbox
    # pad's buttons; SDL maps every other gamepad to them, so a
    # PlayStation pad's cross is +:a+ and its triangle +:y+.
    #
    # [:press] a press at the cursor, as a click there (A, and the right
    #   trigger through Trigger)
    # [:start] the screen's main button: Play on Home, as A on it does
    #   (Start)
    # [:leave] Back, Close or Home, and on Home, Quit, asked twice (B)
    # [:select] Settings on Home, and Sound in Settings (View, Back,
    #   Select, or Share: SETTINGS)
    # [:x], [:y], [:lb], [:rb] each screen's own buttons, labelled on it
    #
    # The d-pad has no intent of its own: it moves the cursor, as the left
    # stick does (GamepadCursor); the right stick scrolls a list. B, X, and
    # the shoulders do nothing during a game.
    class GamepadButtons < Data.define(:intents)
      # The button that opens Settings from Home, as a console's View or
      # Select button opens a game's options.
      SETTINGS = :back

      STANDARD = { a: :press, start: :start, y: :y, x: :x, b: :leave, SETTINGS => :select, leftshoulder: :lb,
                   rightshoulder: :rb }.freeze

      def initialize(intents: STANDARD) = super

      # The intent of a press of +button+, or nil for a button that has none.
      def intent(button) = intents[button.to_s.to_sym]
    end

    # The right trigger, as a button: it presses once when pulled past
    # +style.trigger_press+, and again only after it is let back below
    # +style.trigger_release+. +pressed+ is whether the last pull pressed.
    class Trigger < Data.define(:held, :pressed)
      def self.released = new(held: false, pressed: false)

      # The trigger after it reads +value+, from 0 (let go) to 1.
      def pull(value, style)
        now = held ? value > style.trigger_release : value >= style.trigger_press
        with(held: now, pressed: now && !held)
      end
    end
  end
end
