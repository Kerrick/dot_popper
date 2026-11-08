# frozen_string_literal: true

module DotPopper
  module Groups
    # How a member of a friend group is known: by a Mark, a number from 0
    # to COUNT - 1 that the game draws as a dot in its own colour and
    # shape (Presentation::Look::MARKS). A mark is the only identity a
    # player has: no name, no word, nothing a player supplies, so there is
    # nothing to filter, report or block. There are as many marks as a group
    # has room for, and the server gives each member of a group their own.
    # The game and its server both use this file.
    module Mark
      COUNT = 8

      module_function

      # Whether +value+ is a mark (an Integer, not a numeral or a float).
      def valid?(value) = value.is_a?(Integer) && value >= 0 && value < COUNT

      # The first mark not in +taken+, or nil when all are.
      def free(taken) = (0...COUNT).find { !taken.include?(it) }
    end
  end
end
