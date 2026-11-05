# frozen_string_literal: true

module DotPopper
  module Presentation
    # The title screen as it shows at a moment: how far its entrance has
    # come, and the prompt's breath.
    class Marquee
      attr_reader :best

      def initialize(look, best:, at:)
        @look = look
        @best = best
        @at = at
      end

      def intro(now) = @look.intro.at(now - @at)

      # The prompt breathes, between half and fully opaque, once every
      # +breath+ seconds.
      def prompt(now) = 0.75 - (0.25 * Math.cos((now - @at) * 2 * Math::PI / @look.breath))
    end
  end
end
