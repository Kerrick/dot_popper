# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every word the game shows, and the way it writes numbers. The words
    # are for someone who has never played: each says what happened or
    # what a press will do, in full sentences where a sentence is needed,
    # with no name the game made up for itself. The words that say what to
    # do are ByInputs, said as a tap, a click, or a gamepad's button,
    # whichever +input+ (InputKind) the player last used (#for): +play+,
    # +continue+, +go_back+, +credits+, +share+, +how_to_play+ and the
    # share preview's +copy+ and +close+. +labels+ name the Records
    # screen's sections
    # and rows, by what they count. +goals+ say each kind of DailyGoal as
    # the end of "Today's goal: ...", with %d for its target. +screen_size+
    # says how big a screen is, in dots, with %d for its width and height,
    # and names the choices of dot size (DotSizing) by what they do here.
    class Words < Data.define(:title, :play, :continue, :time_up, :new_best, :best, :score, :time,
                              :share, :share_heading, :copied, :copy, :close, :records, :how_to_play, :go_back,
                              :no_rounds, :clear, :keep_holding, :hold_to_clear, :cleared, :undo, :labels, :goals, :goal_done, :goal_met,
                              :screen_size, :credits, :credits_title, :notice, :quit_again, :full_screen, :windowed, :quit, :looks, :offer,
                              :input)
      MINUS = "−" # a true minus sign, as wide as the plus
      # How near a round must come to the best for Game Over to say by how
      # much; further off, the gap is only a number to dwell on.
      CLOSE_TO_BEST = 3

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

      def initialize(input: InputKind::MOUSE, **) = super

      # These words as said to a player using +input+ (InputKind).
      def for(input) = with(input:)

      def play = super.for(input)
      def continue = super.for(input)
      def go_back = super.for(input)
      def clear = super.for(input)
      def hold_to_clear = super.for(input)
      def undo = super.for(input)
      def credits = super.for(input)
      def share = super.for(input)
      def how_to_play = super.for(input)
      def copy = super.for(input)
      def close = super.for(input)

      # What the title's fullscreen button says it does: "Full screen" in
      # a window, and back in fullscreen, "Window".
      def fullscreen_button(fullscreen) = fullscreen ? windowed : full_screen

      # What the Records screen says while "Clear my records…" is held:
      # on a gamepad, naming +button+, the one held ("A" or "Y").
      def keep_holding(button) = super().for(input).sub("%s", button.to_s)

      # What the title says of the plays left, where plays are counted: "23
      # plays left", or "No plays left today".
      def plays_left(left) = left.positive? ? "#{Words.count(left, "play")} left" : "No plays left today"

      # The offer's note, plain about what free play there is and when more
      # comes: "No free plays left. 3 new free plays come tomorrow."
      def offer_note(left, daily)
        coming = "#{daily} new free plays"
        return "No free plays left. #{coming} come tomorrow." unless left.positive?

        "#{Words.count(left, "free play")} left. #{coming} come every day."
      end

      # "Your best: 27".
      def best_line(best) = "#{self.best}: #{best}"

      # How a finished round compares with the best it did not beat:
      # "3 points short of your best of 27". With no best yet, nothing. A
      # class's +first+ round only says the best it set, "Your best: 18":
      # with nothing before it, it neither tied nor beat anything.
      def short_of_best(score, best, first: false)
        return best_line(best) if first

        gap = best - score
        if gap.positive?
          return "Just #{Words.count(gap, "point")} short of your best of #{best}" if gap <= CLOSE_TO_BEST

          return "Your best is #{best}"
        end

        best.positive? ? "You tied your best of #{best}" : ""
      end

      # The round in one quiet line, so a player can see what it was made
      # of: "14 pops, 2 mistakes, slowest pop 3.1 seconds". The slowest
      # pop is the longest any fresh dot waited before it was popped.
      def summary(stats)
        parts = [Words.count(stats.pops, "pop"), Words.count(stats.slips, "mistake")]
        parts << "slowest pop #{format("%.1f", stats.longest_wait)} seconds" if stats.pops.positive?
        parts.join(", ")
      end

      # The one lifetime record a round set that Game Over names (the most
      # impressive, LifetimeStats::Record::ORDER), as a sentence:
      # "New record: 18 pops in a row without a mistake".
      def record(record)
        value = record.value
        "New record: " +
          case record.kind
          when :longest_run then "#{Words.count(value.to_i, "pop")} in a row without a mistake"
          when :longest_round then "your longest round, #{Words.count(value.round, "second")}"
          when :longest_wait then "you waited #{Words.tenths(value)} seconds for a dot, then popped it"
          else "your fastest pop, #{Words.tenths(value)} seconds after the dot appeared"
          end
      end

      # What "Share my score" offers to share, and its Copy puts on the
      # clipboard: the score, whether it set or tied the player's +best+,
      # the lifetime +record+ it set, if any, what the round was made of,
      # and the +screen+ it was played on (#played_on), since a score
      # depends on that.
      #
      #   Dot Popper: 25 points, a new best!
      #   New record: 18 pops in a row without a mistake
      #   🟡 27 pops · ⚫ 1 mistake · ⏱ 38 seconds
      #   Played on a screen about 12 dots wide and 8 dots tall.
      def share_text(score, stats, best:, new_best:, record: nil, screen: nil, first: false)
        ["Dot Popper: #{Words.count(score, "point")}#{best_note(score, best, new_best) unless first}",
         (self.record(record) if record),
         "🟡 #{Words.count(stats.pops, "pop")} · ⚫ #{Words.count(stats.slips, "mistake")} · " \
         "⏱ #{Words.count(stats.duration.round, "second")}",
         screen].compact.join("\n")
      end

      # What the Records screen says about the screen, given its +field+
      # and the player's DotSizing: how big it is, counted in dots side by
      # side, and, with the dots fitted to it, what that does.
      #
      #   This screen is about 12 dots wide and 8 dots tall.
      #   Dots are sized to fit this screen, so scores compare across devices.
      def screen_notes(field, sizing)
        [screen_here(field), (screen_size.fetch(:fitted_here) if sizing.sized_to_screen?)].compact
      end

      # "This screen is about 12 dots wide and 8 dots tall."
      def screen_here(field) = format(screen_size.fetch(:here), *Words.dots_across(field))

      # The shared result's last line: "Played on a screen about 12 dots
      # wide and 8 dots tall.", or, with the dots +sized+ to the screen,
      # that they were.
      def played_on(field, sized: false)
        sized ? screen_size.fetch(:fitted_played) : format(screen_size.fetch(:played), *Words.dots_across(field))
      end

      # The name of one choice of dot size, on its segment of the title's
      # "Dot size" control, by what it does on this screen next to the
      # other, as the +preview+ (SizingPreview) sees it: on a phone,
      # fitting the dots to the screen gives "Smaller dots" and the fixed
      # size "Bigger dots"; on a big monitor, the other way about. A
      # player chooses what they see, not how the size is worked out.
      def sizing(sizing, preview) = screen_size.fetch(effect_of(sizing, preview))

      # What else that choice does, under its name: "More room" for the
      # smaller dots, "Less room" for the bigger.
      def sizing_note(sizing, preview) = screen_size.fetch(:"#{effect_of(sizing, preview)}_note")

      # The control's label: "Dot size".
      def sizing_label = screen_size.fetch(:choice)

      # The Records screen's heading for the bests it shows: "Your bests
      # with standard dots on screens this size".
      def bests_heading(sizing) = labels.fetch(sizing.sized_to_screen? ? :fitted_bests : :bests)

      # The line under the Records screen's chart, when some of its bars
      # are of rounds that do not count toward the bests shown: "Brighter
      # bars are rounds with dots sized to the screen."
      def chart_note(sizing) = labels.fetch(sizing.sized_to_screen? ? :fitted_chart_note : :chart_note)

      # How many dots fit across +field+ and down it, side by side, to the
      # nearest whole dot, and never none.
      def self.dots_across(field)
        across = 2 * field.radius
        [field.width, field.height].map { [(it / across).round, 1].max }
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
      # row without a mistake."
      def goal(goal) = "Today's goal: #{format(goals.fetch(goal.kind), goal.target)}."

      # Today's goal once it is met, still saying what it was, since a
      # player who met it wants to see what they did: "Done today: keep one
      # round going for 40 seconds."
      def goal_done_line(goal) = "#{goal_done} #{format(goals.fetch(goal.kind), goal.target)}."

      # The days in a row the goal has been met, for the title once there
      # are two or more, under the goal it counts: "Met 3 days in a row."
      def streak(days) = "Met #{days} days in a row."

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


      private

      def best_note(score, best, new_best)
        if new_best then ", a new best!"
        elsif score == best && best.positive? then ", tying my best!"
        else ""
        end
      end

      # :smaller or :bigger: what +sizing+ does to the dots here, next to
      # the other choice; :alike where the two hardly differ.
      def effect_of(sizing, preview)
        effect = preview.effect
        sizing.sized_to_screen? ? effect : { smaller: :bigger, bigger: :smaller }.fetch(effect, effect)
      end
    end
  end
end
