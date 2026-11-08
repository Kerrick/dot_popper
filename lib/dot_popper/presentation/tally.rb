# frozen_string_literal: true

module DotPopper
  module Presentation
    # A change to the score or the clock as the game shows it without a
    # word, in the Tutorial's flights and the title's legend alike: a
    # signed number, "+1" or "−2", and for the clock a small drawn
    # stopwatch after it (+stopwatch+). The stopwatch is ICON of the
    # line's height across, GAP of its own size after the number.
    class Tally < Data.define(:text, :stopwatch)
      ICON = 0.62
      GAP = 0.25

      def self.points(points) = new(text: Words.points(points), stopwatch: false)
      def self.seconds(seconds) = new(text: Words.points(seconds), stopwatch: true)

      # What a pop does, and what a tap on a popped dot does, as the
      # rules say, each as its points and its seconds.
      def self.pop = [points(Rules::POP_POINTS), seconds(Rules::POP_SECONDS)]
      def self.penalty = [points(-Rules::PENALTY_POINTS), seconds(-Rules::PENALTY_SECONDS)]

      # The stopwatch's size on a line +height+ tall.
      def self.icon(height) = height * ICON

      # How wide it is on a line +height+ tall, its number as the block
      # measures it.
      def width(height)
        number = yield(text)
        stopwatch ? number + (Tally.icon(height) * (1 + GAP)) : number
      end
    end
  end
end
