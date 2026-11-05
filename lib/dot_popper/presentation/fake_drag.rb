# frozen_string_literal: true

module DotPopper
  module Presentation
    # DOT_POPPER_FAKE_DRAG=0.5,0.9,0.3,0.3: a drag of the game-over pile
    # made up for checking it without a hand, from the first point to the
    # second, each as fractions of the window's width and height. On each
    # Game Over, +wait+ seconds in, it presses near the first point, moves
    # to the second over +travel+ seconds, and lets go there still
    # moving, so the dot is thrown.
    class FakeDrag
      def self.parse(text, wait: 1.2, travel: 1.0)
        numbers = text.to_s.split(",").map { Float(it, exception: false) }
        new(*numbers, wait:, travel:) if numbers.size == 4 && numbers.all?
      end

      def initialize(from_x, from_y, to_x, to_y, wait:, travel:)
        @from = [from_x, from_y]
        @to = [to_x, to_y]
        @wait = wait
        @travel = travel
        @shown_at = nil
      end

      # Yields each step due at +now+ on a Game Over shown since +shown_at+,
      # in a window +width+ by +height+: :press, :move, or :release, with
      # where.
      def step(shown_at, now, width, height)
        @shown_at, @phase = shown_at, :waiting unless @shown_at == shown_at
        progress = (now - shown_at - @wait) / @travel
        return if progress.negative? || @phase == :done

        x, y = at([progress, 1.0].min, width, height)
        if @phase == :waiting
          @phase = :dragging
          yield :press, *at(0.0, width, height)
        end
        yield :move, x, y
        return if progress < 1.0

        @phase = :done
        yield :release, x, y
      end

      private

      def at(progress, width, height)
        [(@from[0] + ((@to[0] - @from[0]) * progress)) * width, (@from[1] + ((@to[1] - @from[1]) * progress)) * height]
      end
    end
  end
end
