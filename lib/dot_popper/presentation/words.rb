# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every word the game shows, and the way it writes numbers.
    # +covered+ is the first-run hint, a sentence a line.
    class Words < Data.define(:title, :play, :continue, :time_up, :new_best, :best, :score, :time, :covered,
                              :daily, :share, :copied, :new_daily_best, :daily_best)
      MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
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

      # "Daily · Nov 5".
      def daily_label(date) = "#{daily} · #{MONTHS[date.month - 1]} #{date.day}"

      # "Today's best 27".
      def daily_best_line(best) = "#{daily_best} #{best}"

      # What Share copies: the day, the score, and how it was made, with
      # nothing that gives the day's dots away.
      def share_text(date, score, stats)
        "Dot Popper Daily · #{date.iso8601} · #{Words.count(score, "point")}\n" \
          "🟡 #{Words.count(stats.pops, "pop")} · ⚫ #{Words.count(stats.slips, "slip")} · ⏱ #{stats.duration.round} s"
      end

      # "1 pop", "2 pops".
      def self.count(number, noun) = "#{number} #{noun}#{"s" unless number == 1}"
    end
  end
end
