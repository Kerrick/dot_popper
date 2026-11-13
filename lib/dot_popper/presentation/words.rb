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
    class Words < Data.define(:game_name, :play, :play_again, :time_up, :new_score_record, :score_record, :score, :time,
                              :share, :share_heading, :copied, :copy, :close, :stats, :how_to_play, :go_back,
                              :no_games, :clear, :keep_holding, :hold_to_clear, :cleared, :undo, :labels, :goals, :goal_done, :goal_met,
                              :screen_size, :credits, :credits_heading, :notice, :quit_again, :quit, :themes, :offer, :buttons,
                              :input)
      MINUS = "−" # a true minus sign, as wide as the plus
      # How near a game must come to the best for Game Over to say by how
      # much; further off, the gap is only a number to dwell on.
      CLOSE_TO_SCORE_RECORD = 3

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
      def play_again = super.for(input)
      def go_back = super.for(input)
      def clear = super.for(input)
      def hold_to_clear = super.for(input)
      def undo = super.for(input)
      def credits = super.for(input)
      def share = super.for(input)
      def how_to_play = super.for(input)
      def copy = super.for(input)
      def close = super.for(input)
      def quit = super.for(input)
      def settings = button(:settings)

      # A button's word, said as the player's input would press it.
      def button(name)
        word = buttons.fetch(name)
        word.is_a?(ByInput) ? word.for(input) : word
      end

      # A large button's word on Home, its small value, and on a controller the button in its corner.
      def tile(name) = buttons.fetch(:"tile_#{name}")
      def tile_note(name) = buttons.fetch(:"tile_note_#{name}")
      def tile_badge(name) = buttons.fetch(:"badge_#{name}")

      # "Today's goal", the goal's sentence on its card, and what stands
      # under the days in a row.
      def goal_card_label = buttons.fetch(:goal_label)
      def goal_sentence(goal) = "#{format(goals.fetch(goal.kind), goal.target).capitalize}."
      def streak_days(days) = days == 1 ? "day" : "days"
      def streak_in_a_row = buttons.fetch(:in_a_row)

      # "1 of 3 titles".
      def titles_held(held, groups) = "#{held} of #{groups} #{groups == 1 ? "title" : "titles"}"

      # What the Stats screen says while "Clear my stats…" is held:
      # on a gamepad, naming +button+, the one held ("A" or "Y").
      def keep_holding(button) = super().for(input).sub("%s", button.to_s)

      # What the title says of the games left, where games are counted: "23
      # games left", or "No games left today".
      def games_left(left) = left.positive? ? "#{Words.count(left, "game")} left" : "No games left today"

      # What stands under Get Pro when no game is left: "No games left today. 3 more tomorrow."
      def no_games_left(daily) = "No games left today. #{daily} more tomorrow."

      # The offer's note, plain about how many games are left and how many
      # come each day: "No games left today. 3 games a day." It never says
      # "20 free games" alone, which would hide that most come a day at a time.
      def offer_note(left, daily)
        coming = "#{daily} games a day"
        return "No games left today. #{coming}." unless left.positive?

        "#{Words.count(left, "game")} left. #{coming}."
      end

      # What the offer lists, +focus+ (:games, :achievements, :themes or
      # :groups) first, so it opens with the thing the player tapped.
      def offer_items(focus = nil)
        first, rest = offer.fetch(:includes).partition { |key, _| key == focus }
        (first + rest).map(&:last)
      end

      # "Your record: 27".
      def score_record_line(score_record) = "#{self.score_record}: #{score_record}"

      # How a finished game compares with the best it did not beat:
      # "3 points short of your record of 27". With no best yet, nothing. A
      # class's +first+ game only says the best it set, "Your record: 18":
      # with nothing before it, it neither tied nor beat anything.
      def short_of_score_record(score, score_record, first: false)
        return score_record_line(score_record) if first

        gap = score_record - score
        if gap.positive?
          return "Just #{Words.count(gap, "point")} short of your record of #{score_record}" if gap <= CLOSE_TO_SCORE_RECORD

          return "Your record is #{score_record}"
        end

        score_record.positive? ? "You tied your record of #{score_record}" : ""
      end

      # What the game was made of, each fact a sign and a number, so it
      # reads in any language: the bright dots popped, the mistakes, and
      # how long the game lasted, in seconds, as the game's own "+1s".
      def self.facts(stats) = [[:bright, stats.dots_popped.to_s], [:popped, stats.mistakes.to_s], [:stopwatch, "#{stats.duration.round}s"]]

      # The one lifetime record a game set that Game Over names (the most
      # impressive, Stats::Record::ORDER), as a sentence:
      # "New record: 18 dots in a row without a mistake".
      def record(record)
        value = record.value
        "New record: " +
          case record.kind
          when :most_dots_in_a_row then "#{Words.count(value.to_i, "dot")} in a row without a mistake"
          when :longest_game then "your longest game, #{Words.count(value.round, "second")}"
          when :longest_time_to_pop then "your longest time to pop, #{Words.tenths(value)} seconds"
          else "your shortest time to pop, #{Words.tenths(value)} seconds"
          end
      end

      # What "Share my score" offers to share, and its Copy puts on the
      # clipboard: the score, whether it set or tied the player's +best+,
      # the lifetime +record+ it set, if any, what the game was made of,
      # and the +screen+ it was played on (#played_on), since a score
      # depends on that.
      #
      #   Dot Popper: 25 points, a new record!
      #   New record: 18 dots in a row without a mistake
      #   🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds
      #   Played on a screen about 12 dots wide and 8 dots tall.
      def share_text(score, stats, score_record:, new_score_record:, record: nil, screen: nil, first: false)
        ["Dot Popper: #{Words.count(score, "point")}#{score_record_note(score, score_record, new_score_record) unless first}",
         (self.record(record) if record),
         "🟡 #{Words.count(stats.dots_popped, "dot")} · ⚫ #{Words.count(stats.mistakes, "mistake")} · " \
         "⏱ #{Words.count(stats.duration.round, "second")}",
         screen].compact.join("\n")
      end

      # "This screen is about 12 dots wide and 8 dots tall."
      def screen_here(field) = format(screen_size.fetch(:here), *Words.dots_across(field))

      # The shared result's last line: "Played on a screen about 12 dots
      # wide and 8 dots tall.", or, with the dots +sized+ to the screen,
      # that they were.
      def played_on(field, sized: false)
        sized ? screen_size.fetch(:fitted_played) : format(screen_size.fetch(:played), *Words.dots_across(field))
      end

      # The name of one choice of dot size, on its segment of Home's
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

      # The Stats screen's heading for the records it shows: "Your stats
      # with standard dots on screens this size".
      def records_heading(sizing) = labels.fetch(sizing.sized_to_screen? ? :fitted_records : :records)

      # The line under the Stats screen's chart, when some of its bars
      # are of games that do not count toward the records shown: "Brighter
      # bars are games with dots sized to the screen."
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

      # Today's goal on Home: "Today's goal: pop 15 bright dots in a
      # row without a mistake."
      def goal(goal) = "Today's goal: #{format(goals.fetch(goal.kind), goal.target)}."

      # Today's goal once it is met, still saying what it was, since a
      # player who met it wants to see what they did: "Done today: keep one
      # game going for 40 seconds."
      def goal_done_line(goal) = "#{goal_done} #{format(goals.fetch(goal.kind), goal.target)}."

      # The days in a row the goal has been met, for Home once there
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

      # The chart's caption: "Your last 20 games", or "Your last game".
      def self.last_games(count) = count == 1 ? "Your last game" : "Your last #{count} games"

      # "1 game", "2 games".
      def self.count(number, noun) = "#{number} #{noun}#{"s" unless number == 1}"


      private

      def score_record_note(score, score_record, new_score_record)
        if new_score_record then ", a new record!"
        elsif score == score_record && score_record.positive? then ", tying my record!"
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
