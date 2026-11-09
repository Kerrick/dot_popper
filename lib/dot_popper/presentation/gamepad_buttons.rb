# frozen_string_literal: true

module DotPopper
  module Presentation
    # What each gamepad button asks for, by the names LÖVE gives an Xbox
    # pad's buttons; SDL maps every other gamepad to them, so a
    # PlayStation pad's cross is +:a+ and its triangle +:y+.
    #
    # [:press] a press at the cursor, as a click there (A, and the right
    #   trigger through Trigger)
    # [:start] start a game from the title, or continue after one, or
    #   leave the Stats screen (Start)
    # [:share] copy the result on Game Over, or on the Stats screen,
    #   held, clear the records, and pressed again, undo that; on the
    #   title, where there is nothing to share, How to play (Y)
    # [:records] open the Stats screen from the title (X), and on the
    #   Stats screen, the Credits screen
    # [:leave] leave the Credits screen, or the Stats screen (B)
    # [:mute] sound on or off (Back, Select, or Share), on every screen
    # [:sizing] switch how dots are sized, on the title once it offers the
    #   choice (either shoulder button)
    #
    # The d-pad has no intent of its own: it moves the cursor, as the left
    # stick does (GamepadCursor). B, X, and the shoulders do nothing during a game.
    class GamepadButtons < Data.define(:intents)
      STANDARD = { a: :press, start: :start, y: :share, x: :stats, b: :leave, back: :mute, leftshoulder: :sizing,
                   rightshoulder: :sizing }.freeze

      def initialize(intents: STANDARD) = super

      # The intent of a press of +button+, or nil for a button that has none.
      def intent(button) = intents[button.to_s.to_sym]
    end

    # The right trigger, as a button: it presses once when pulled past
    # +look.trigger_press+, and again only after it is let back below
    # +look.trigger_release+. +pressed+ is whether the last pull pressed.
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
