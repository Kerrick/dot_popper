# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every word the game shows, and the way it writes numbers.
    # +covered+ is the first-run hint, a sentence a line.
    class Words < Data.define(:title, :play, :continue, :time_up, :new_best, :best, :score, :time, :covered)
      MINUS = "−" # a true minus sign, as wide as the plus

      # +1, −2, or 0 for a number of points.
      def self.points(points) = signed(points)

      # +1s or −2s for a number of seconds.
      def self.seconds(seconds) = "#{signed(seconds)}s"

      # The whole seconds left on a clock, never below zero.
      def self.clock(countdown) = [countdown.whole_seconds, 0].max.to_s

      def self.signed(number)
        whole = number.round(1)
        whole = whole.to_i if whole == whole.round
        if whole.positive? then "+#{whole}"
        elsif whole.negative? then "#{MINUS}#{whole.abs}"
        else "0"
        end
      end

      def best_line(best) = "#{self.best} #{best}"

      # How far a finished round fell short of the best, which it did not
      # beat: "3 short of your best (27)".
      def short_of_best(score, best)
        gap = best - score
        gap.positive? ? "#{gap} short of your best (#{best})" : "You matched your best (#{best})"
      end

      # The round in one quiet line: "14 pops · 2 slips · longest wait 3.1 s".
      def summary(stats)
        parts = [Words.count(stats.pops, "pop"), Words.count(stats.slips, "slip")]
        parts << "longest wait #{format("%.1f", stats.longest_wait)} s" if stats.pops.positive?
        parts.join(" · ")
      end

      # "1 pop", "2 pops".
      def self.count(number, noun) = "#{number} #{noun}#{"s" unless number == 1}"
    end
  end
end
