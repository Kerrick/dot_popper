# frozen_string_literal: true

module DotPopper
  module Presentation
    # A key a screen takes, and what it does there: +keys+, the keys it
    # answers, by the game's names (Shell::LotaInput#key); +with+, the
    # modifier keys of which one must be held, and no other (none: the
    # key alone, with no modifier key held, since a chord is no press of
    # the plain key); +held_or_not+, true where the key is the same with
    # any modifier keys held or none (a license key's letters); and
    # +does+, the name of what it does: a method of the screen (or, for
    # the keys every screen takes, of the InputHandler) given the key,
    # which says whether it took it. A key it does not take goes on to
    # the next binding.
    class KeyBinding < Data.define(:keys, :with, :held_or_not, :does)
      # Ctrl, or Cmd on a Mac: the system's shortcuts.
      COMMAND = %i[ctrl command].freeze

      def initialize(keys:, does:, with: [], held_or_not: false) = super(keys: Array(keys).freeze, with: with.freeze, held_or_not:, does:)

      # Whether this binding answers +press+ (KeyPress): its key, held
      # with exactly the modifier keys it binds.
      def answers?(press)
        return false unless keys.include?(press.key)
        return true if held_or_not

        with.empty? ? press.held.empty? : press.held?(*with) && (press.held - with).empty?
      end

      # What a button pressed by this key shows for it: "Ctrl+B", or "⌘B"
      # where the system's command key is Cmd (+command_key+).
      def hint(command_key:)
        key = keys.first.to_s.upcase
        return key unless with == COMMAND

        command_key ? "⌘#{key}" : "Ctrl+#{key}"
      end
    end
  end
end
