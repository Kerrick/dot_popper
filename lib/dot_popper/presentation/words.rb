# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every word the game shows, and the way it writes numbers. The words
    # are for someone who has never played: each says what happened or
    # what a tap will do, in full sentences where a sentence is needed,
    # with no name the game made up for itself. +covered+ is the first-run
    # hint, a sentence a line. +labels+ name the Records screen's sections
    # and rows, by what they count. +goals+ say each kind of DailyGoal as
    # the end of "Today's goal: ...", with %d for its target.
    class Words < Data.define(:title, :play, :continue, :time_up, :new_best, :best, :score, :time, :covered,
                              :share, :copied, :records, :go_back, :no_rounds, :labels, :goals, :goal_done,
                              :goal_met)
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

      # The one lifetime record a round set that Game Over names (the most
      # impressive, LifetimeStats::Record::ORDER), as a sentence:
      # "New record: 18 pops in a row without a wrong tap".
      def record(record)
        value = record.value
        "New record: " +
          case record.kind
          when :longest_run then "#{Words.count(value.to_i, "pop")} in a row without a wrong tap"
          when :longest_round then "your longest round, #{Words.count(value.round, "second")}"
          when :longest_wait then "you waited #{Words.tenths(value)} seconds for a dot, then popped it"
          else "your fastest pop, #{Words.tenths(value)} seconds after the dot appeared"
          end
      end

      # What "Copy my result" puts on the clipboard: the score, whether it
      # set or tied the player's +best+, the lifetime +record+ it set, if
      # any, and what the round was made of.
      #
      #   Dot Popper: 25 points, a new best!
      #   New record: 18 pops in a row without a wrong tap
      #   🟡 27 pops · ⚫ 1 wrong tap · ⏱ 38 seconds
      def share_text(score, stats, best:, new_best:, record: nil)
        ["Dot Popper: #{Words.count(score, "point")}#{best_note(score, best, new_best)}",
         (self.record(record) if record),
         "🟡 #{Words.count(stats.pops, "pop")} · ⚫ #{Words.count(stats.slips, "wrong tap")} · " \
         "⏱ #{Words.count(stats.duration.round, "second")}"].compact.join("\n")
      end

      # Seconds to one decimal place: "0.4".
      def self.tenths(seconds) = format("%.1f", seconds)

      # A time to one decimal place, "0.4 seconds", or "None yet" for a
      # time that nothing has set: nil, or nothing at all.
      def seconds_or_none(seconds)
        seconds.to_f.positive? ? "#{Words.tenths(seconds)} seconds" : labels[:none]
      end

      # A long time in the largest whole units that suit it: "45 seconds",
      # "31 minutes", "2 hours 5 minutes".
      def self.duration(seconds)
        whole = seconds.floor
        return count(whole, "second") if whole < 60

        minutes = whole / 60
        return count(minutes, "minute") if minutes < 60

        hours = count(minutes / 60, "hour")
        (minutes % 60).zero? ? hours : "#{hours} #{count(minutes % 60, "minute")}"
      end

      # Today's goal on the title: "Today's goal: pop 15 bright dots in a
      # row without tapping a popped one."
      def goal(goal) = "Today's goal: #{format(goals.fetch(goal.kind), goal.target)}."

      # The days in a row the goal has been met, for the title once there
      # are two or more: "You've met the daily goal 3 days in a row."
      def streak(days) = "You've met the daily goal #{days} days in a row."

      # +text+ broken between words into lines no wider than +room+, as
      # the block measures a line. A single word wider than +room+ keeps a
      # line of its own.
      def self.wrap(text, room, &width)
        text.split.each_with_object([]) do |word, lines|
          joined = [lines.last, word].compact.join(" ")
          if lines.any? && width.call(joined) <= room then lines[-1] = joined
          else lines << word
          end
        end
      end

      # +text+ wrapped into as few lines as #wrap needs for +room+, but
      # with those lines as even as they can be, so no word is left alone
      # on the last.
      def self.balance(text, room, &width)
        lines = wrap(text, room, &width)
        return lines if lines.size < 2

        narrowest = (room * 0.5).floor
        (narrowest..room).step([room / 50, 1].max).each do |tried|
          even = wrap(text, tried, &width)
          return even if even.size == lines.size
        end
        lines
      end

      # The chart's caption: "Your last 20 rounds", or "Your last round".
      def self.last_rounds(count) = count == 1 ? "Your last round" : "Your last #{count} rounds"

      # "1 pop", "2 pops".
      def self.count(number, noun) = "#{number} #{noun}#{"s" unless number == 1}"

      # A signed change with its unit: "+1 point", "−2 seconds".
      def self.change(number, noun) = "#{signed(number)} #{noun}#{"s" unless number.abs == 1}"

      private

      def best_note(score, best, new_best)
        if new_best then ", a new best!"
        elsif score == best && best.positive? then ", tying my best!"
        else ""
        end
      end
    end
  end
end
