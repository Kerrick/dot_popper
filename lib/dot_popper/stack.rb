# frozen_string_literal: true

module DotPopper
  # The dots in drawing order. The oldest dot is on top, and each new dot
  # goes in underneath every dot already here. That ordering is the game:
  # popped dots crowd the top, and a fresh one has to come out from under
  # them before it can be tapped.
  class Stack < Data.define(:dots)
    include Enumerable

    # +dots+ are top first.
    def initialize(dots: []) = super(dots: dots.dup.freeze)

    def slide_under(dot) = with(dots: dots + [dot])

    # The topmost dot under a point, or nil. A tap reaches only this dot,
    # never one beneath it.
    def top_at(x, y) = dots.find { |dot| dot.covers?(x, y) }

    # The stack with +dot+ in place of the dot that has its id.
    def replace(dot) = with(dots: dots.map { |each| each.id == dot.id ? dot : each })

    # The stack with every dot passed through the block, order kept.
    def map_dots(&) = with(dots: dots.map(&))

    # Top first.
    def each(&) = dots.each(&)

    # Bottom first, the order to draw in.
    def bottom_up = dots.reverse_each

    def size = dots.size
  end
end
