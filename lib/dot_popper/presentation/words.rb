# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every word the game shows, and the way it writes numbers. The words
    # are for someone who has never played: each says what happened or
    # what a tap will do, in full sentences where a sentence is needed,
    # with no name the game made up for itself. +covered+ is the first-run
    # hint, a sentence a line.
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

      # "Your best: 27".
      def best_line(best) = "#{self.best}: #{best}"

      # The title's two lines that teach the scoring, one beside each kind
      # of dot: "Tap a bright dot: +1 point, +1 second".
      def legend_fresh = "Tap a bright dot: #{Words.change(Rules::POP_POINTS, "point")}, " \
                         "#{Words.change(Rules::POP_SECONDS, "second")}"
      def legend_popped = "Tap a popped dot: #{Words.change(-Rules::PENALTY_POINTS, "point")}, " \
                          "#{Words.change(-Rules::PENALTY_SECONDS, "second")}"

      # How a finished round compares with the best it did not beat:
      # "3 points short of your best of 27". With no best yet, nothing.
      def short_of_best(score, best)
        gap = best - score
        return "#{Words.count(gap, "point")} short of your best of #{best}" if gap.positive?

        best.positive? ? "You tied your best of #{best}" : ""
      end

      # The round in one quiet line, so a player can see what it was made
      # of: "14 pops, 2 wrong taps, slowest pop 3.1 seconds". The slowest
      # pop is the longest any fresh dot waited before it was popped.
      def summary(stats)
        parts = [Words.count(stats.pops, "pop"), Words.count(stats.slips, "wrong tap")]
        parts << "slowest pop #{format("%.1f", stats.longest_wait)} seconds" if stats.pops.positive?
        parts.join(", ")
      end

      # The heading over a daily round's result: "Today's challenge, Nov 5".
      def daily_label(date) = "Today's challenge, #{MONTHS[date.month - 1]} #{date.day}"

      # "Your best today: 27".
      def daily_best_line(best) = "#{daily_best}: #{best}"

      # What "Copy my result" puts on the clipboard: the day, the score, and
      # how it was made, with nothing that gives the day's dots away.
      def share_text(date, score, stats)
        "Dot Popper, today's challenge (#{date.iso8601}): #{Words.count(score, "point")}\n" \
          "🟡 #{Words.count(stats.pops, "pop")} · ⚫ #{Words.count(stats.slips, "wrong tap")} · " \
          "⏱ #{Words.count(stats.duration.round, "second")}"
      end

      # "1 pop", "2 pops".
      def self.count(number, noun) = "#{number} #{noun}#{"s" unless number == 1}"

      # A signed change with its unit: "+1 point", "−2 seconds".
      def self.change(number, noun) = "#{signed(number)} #{noun}#{"s" unless number.abs == 1}"
    end
  end
end
