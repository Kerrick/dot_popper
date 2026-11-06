# frozen_string_literal: true

module DotPopper
  module Presentation
    # The few dots that drift behind the title, popped ones over fresh, as
    # in play, but slower. They are the rules' own dots, moved by the
    # rules' own bounce, and nothing taps them.
    class Attract < Data.define(:field, :dots)
      def self.spawn(field, look, random: Random.new(3))
        dots = (0...look.dots).reduce(Stack.new) do |stack, id|
          dot = Dot.spawn(field, random, id:)
          # The older half are popped, so they sit on top, as they would.
          stack.slide_under(dot.with(velocity_x: dot.velocity_x * look.drift, velocity_y: dot.velocity_y * look.drift,
                                     popped: id < look.dots / 2))
        end
        new(field:, dots:)
      end

      def update(seconds) = with(dots: dots.map_dots { it.move(seconds, field) })

      def refit(field) = with(field:, dots: dots.map_dots { it.refit(self.field, field) })
    end
  end
end
