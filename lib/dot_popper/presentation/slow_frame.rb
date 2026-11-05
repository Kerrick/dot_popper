# frozen_string_literal: true

module DotPopper
  module Presentation
    # One frame that took long enough to notice, and what was going on, so
    # a playtest's report can say why: the screen the game was on, the
    # last thing that happened and how long before, and how many garbage
    # collections ran during the frame.
    class SlowFrame < Data.define(:seconds, :screen, :recent, :since, :major_gcs, :minor_gcs)
      THRESHOLD = 0.05 # seconds; a 20-frames-a-second hitch or worse

      def self.slow?(seconds) = seconds >= THRESHOLD

      def report
        parts = ["slow frame #{format("%.1f", seconds * 1000)} ms on #{screen}"]
        parts << "#{format("%.1f", since)} s after #{recent}" if recent
        parts << "garbage collections: #{major_gcs} major, #{minor_gcs} minor"
        parts.join("; ")
      end
    end
  end
end
