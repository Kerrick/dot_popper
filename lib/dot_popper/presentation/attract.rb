# frozen_string_literal: true

module DotPopper
  module Presentation
    # The few dots that drift behind the title, popped ones over fresh, as
    # in play, but slower. They are the rules' own dots, moved by the
    # rules' own bounce, and nothing taps them.
    class Attract
      attr_reader :dots

      def initialize(field, look, random: Random.new(3))
        @field = field
        @look = look
        @random = random
        @dots = Stack.new
        look.dots.times { |id| @dots = @dots.slide_under(dot(id)) }
      end

      def update(seconds) = @dots = @dots.map_dots { it.move(seconds, @field) }

      def field=(field)
        @field = field
        @dots = @dots.map_dots { it.confine(field) }
      end

      private

      # The older half are popped, so they sit on top, as they would.
      def dot(id)
        spawned = Dot.spawn(@field, @random, id:)
        spawned.with(velocity_x: spawned.velocity_x * @look.drift, velocity_y: spawned.velocity_y * @look.drift,
                     popped: id < @look.dots / 2)
      end
    end
  end
end
