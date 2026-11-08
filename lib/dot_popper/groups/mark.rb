# frozen_string_literal: true

module DotPopper
  module Groups
    # How a member of a friend group is known: by a Mark, a number from 0
    # to COUNT - 1 that the game draws as a dot in its own colour and
    # shape (Presentation::Look::MARKS). A mark is the only identity a
    # player has: no name, no word, nothing a player supplies, so there is
    # nothing to filter, report or block. There are as many marks as a group
    # has room for. The server calls the same thing a seat, numbered 1 to
    # COUNT (Mark.of_seat, Mark.seat), and gives each member their own.
    module Mark
      COUNT = 8

      module_function

      # Whether +value+ is a mark (an Integer, not a numeral or a float).
      def valid?(value) = value.is_a?(Integer) && value >= 0 && value < COUNT

      # Whether +value+ is a seat of the server's, 1 to COUNT.
      def seat?(value) = value.is_a?(Integer) && value >= 1 && value <= COUNT

      def seat(mark) = mark + 1
      def of_seat(seat) = seat - 1

      # The first mark not in +taken+, or nil when all are.
      def free(taken) = (0...COUNT).find { !taken.include?(it) }
    end
  end
end
