# frozen_string_literal: true

module DotPopper
  module Presentation
    # How far the game moves on each frame: the time from one frame
    # starting to draw to the next, rather than the time Lota measures
    # from one loop to the next. On Android, a frame waits for a free
    # buffer when it starts to draw, after Lota has measured its time and
    # the game has moved on, so Lota's times swing about the refresh: at
    # 60 Hz a Nord measured 7.5 ms, then 25 ms, and so on, while every
    # frame reached the screen 16.7 ms after the last, and the dots moved
    # unevenly. The waits end in step with the screen, so the time between
    # frames starting to draw is even.
    #
    # +counted+ is when the game's time has been counted up to, and
    # +drawn+ when the latest frame started to draw, or nil if none has
    # since the game last moved on. Every second is counted once, so the
    # game's time keeps up with the clock on the wall; with no frame drawn
    # between (the app in the background, where nothing draws), it counts
    # up to the time of the move.
    class FrameClock < Data.define(:counted, :drawn)
      def self.start = new(counted: nil, drawn: nil)

      # The clock once a frame starts to draw at +time+, in seconds.
      def drawing(time) = with(drawn: time)

      # The clock as the game moves on at +now+, and the seconds it moves
      # on by: +measured+, Lota's, the first time.
      def tick(now, measured)
        return [with(counted: now, drawn: nil), measured] unless counted

        upto = drawn || now
        [with(counted: upto, drawn: nil), [upto - counted, 0.0].max]
      end
    end
  end
end
