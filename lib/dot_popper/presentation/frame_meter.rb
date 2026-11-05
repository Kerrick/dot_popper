# frozen_string_literal: true

module DotPopper
  module Presentation
    # Counts frames for a development report of how smoothly the game
    # runs: every +every+ seconds, the frames a second over that stretch
    # and the longest single frame in it. Each frame's time is the real
    # one, before the game caps what it passes to the rules, so a stall
    # shows up here even though it cannot cost the player time.
    class FrameMeter < Data.define(:every, :elapsed, :frames, :worst)
      def self.start(every) = new(every: every.to_f, elapsed: 0.0, frames: 0, worst: 0.0)

      # The meter after one more frame of +seconds+, and the report line
      # when a stretch has just ended, or nil.
      def record(seconds)
        counted = with(elapsed: elapsed + seconds, frames: frames + 1, worst: [worst, seconds].max)
        return [counted, nil] if counted.elapsed < every

        [FrameMeter.start(every), counted.report]
      end

      def report
        format("%<fps>d frames a second, longest frame %<worst>.1f ms (last %<every>d s)",
               fps: (frames / elapsed).round, worst: worst * 1000, every: every.round)
      end
    end
  end
end
