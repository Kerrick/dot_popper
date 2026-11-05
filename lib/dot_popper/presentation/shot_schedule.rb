# frozen_string_literal: true

module DotPopper
  module Presentation
    # When to capture the screen in a development run
    # (DOT_POPPER_SHOTS="0.5,3,6.5"): seconds since the game started,
    # numbered from 1 in the order written.
    class ShotSchedule < Data.define(:times)
      def self.parse(text)
        new(times: text.to_s.split(",").filter_map { Float(it.strip, exception: false) }.freeze)
      end

      # The numbers of the shots that fall due between +before+ and +now+.
      def due(before, now) = times.each_index.select { |i| times[i] > before && times[i] <= now }.map(&:succ)

      def empty? = times.empty?
    end
  end
end
