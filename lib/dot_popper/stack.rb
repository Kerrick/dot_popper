# frozen_string_literal: true

module DotPopper
  # The dots in drawing order. The oldest dot is on top, and each new dot
  # goes in underneath every dot already here. That ordering is the game:
  # popped dots crowd the top, and a fresh one has to come out from under
  # them before it can be tapped.
  class Stack
    include Enumerable

    def initialize
      @dots = [] # top first
    end

    def slide_under(dot)
      @dots.push(dot)
      dot
    end

    # The topmost dot under a point, or nil. A tap reaches only this dot,
    # never one beneath it.
    def top_at(x, y) = @dots.find { |dot| dot.covers?(x, y) }

    # Top first.
    def each(&) = @dots.each(&)

    # Bottom first, the order to draw in.
    def bottom_up = @dots.reverse_each

    def size = @dots.size
  end
end
