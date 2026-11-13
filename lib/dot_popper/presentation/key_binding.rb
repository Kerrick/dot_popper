# frozen_string_literal: true

module DotPopper
  module Presentation
    # A key a screen takes, and what it does there: +keys+, the keys it
    # answers, by the game's names (Shell::LotaInput#key); +with+, modifier
    # keys of which one must be held (none: held or not, it is the same);
    # +without+, modifier keys none of which may be held; and +does+, the
    # name of what it does: a method of the screen (or, for the keys every
    # screen takes, of the InputHandler) given the key, which says whether
    # it took it. A key it does not take goes on to the next binding.
    class KeyBinding < Data.define(:keys, :with, :without, :does)
      # Ctrl, or Cmd on a Mac: the system's shortcuts.
      COMMAND = %i[ctrl command].freeze

      def initialize(keys:, does:, with: [], without: []) = super(keys: Array(keys).freeze, with: with.freeze, without: without.freeze, does:)

      # Whether this binding answers +press+ (KeyPress).
      def answers?(press) = keys.include?(press.key) && (with.empty? || press.held?(*with)) && !press.held?(*without)

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
