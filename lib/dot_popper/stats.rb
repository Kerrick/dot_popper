# frozen_string_literal: true

module DotPopper
  # Every game this device has played, added up: the totals (games,
  # dots popped, mistakes, seconds, and the distinct days played, counted by
  # +last_day+), the last RECENT scores, oldest first, with the SizeClass
  # each was played in (+recent_classes+, nil where a file written before
  # they were kept does not say), and the daily goal's GoalStreak, across
  # every screen; and for each SizeClass, the
  # Records a game on such a screen can set. Days are ISO 8601 dates
  # ("2026-11-05"), local to the player. The score record stays with
  # ScoreRecord. It saves as lines of +key=value+, a class's records under
  # its name ("medium.most_dots_in_a_row=18"), and reads back whatever it can of
  # a damaged file.
  class Stats < Data.define(:games, :dots_popped, :mistakes, :seconds, :days, :last_day, :recent, :recent_classes,
                                    :streak, :records)
    RECENT = 20
    DAY = /\A\d{4}-\d{2}-\d{2}\z/
    UNKNOWN = "?" # a recent score's class, in a file written before they were kept

    # +recent_classes+ line up with +recent+ from the newest back; a score
    # with none is of an unknown class.
    def initialize(games: 0, dots_popped: 0, mistakes: 0, seconds: 0.0, days: 0, last_day: nil, recent: [], recent_classes: [],
                   streak: GoalStreak.new, records: {})
      classes = ([nil] * recent.size) + recent_classes
      super(games:, dots_popped:, mistakes:, seconds: seconds.to_f, days:, last_day:, recent: recent.dup.freeze,
            recent_classes: classes.last(recent.size).freeze, streak:, records: records.dup.freeze)
    end

    # The stats read from +text+ as #to_text wrote it. A missing, unknown,
    # or unreadable value keeps its starting value. A file written before
    # records were kept by class has them unnamed; they go to +legacy+, the
    # class of the screen the game opens on (see .old?).
    def self.parse(text, legacy: SizeClass::MEDIUM)
      pairs = Pairs.parse(text)
      records = SizeClass::ALL.to_h { [it, Records.parse(pairs.within(it.name))] }
      records[legacy] = Records.parse(pairs) if old?(text)
      new(games: pairs.count(:games), dots_popped: pairs.count(:pops), mistakes: pairs.count(:mistakes),
          seconds: pairs.time(:seconds) || 0.0, days: pairs.count(:days), last_day: pairs.day(:last_day),
          recent: pairs.counts(:recent).last(RECENT), recent_classes: pairs.classes(:recent_classes).last(RECENT),
          streak: GoalStreak.new(current: pairs.count(:goal_streak), longest: pairs.count(:longest_goal_streak),
                                 last_met: pairs.day(:goal_met_on)),
          records: records.reject { |_, each| each.games.zero? })
    end

    # Whether +text+ keeps its records unnamed, as files did before they
    # were kept by class.
    def self.old?(text) = Pairs.parse(text).values.key?("longest_game")

    # The records on screens of +size_class+, or none yet.
    def records_in(size_class) = records.fetch(size_class) { Records.new }

    # The stats after one more game, played on +day+ on a screen of
    # +size_class+.
    def add(stats, day:, size_class:)
      with(games: games + 1, dots_popped: dots_popped + stats.dots_popped, mistakes: mistakes + stats.mistakes, seconds: seconds + stats.duration,
           days: day == last_day ? days : days + 1, last_day: day, recent: (recent + [stats.score]).last(RECENT),
           recent_classes: (recent_classes + [size_class]).last(RECENT),
           records: records.merge(size_class => records_in(size_class).add(stats)))
    end

    # The records a game with +stats+ on a screen of +size_class+ would
    # set, most impressive first (Record::ORDER); see Records#records_set_by.
    def records_set_by(stats, size_class) = records_in(size_class).records_set_by(stats)

    # The total of dots popped saves as "pops", the key every build before
    # it was renamed reads and writes.
    def to_text
      totals = [["games", games], ["pops", dots_popped], ["mistakes", mistakes], ["seconds", seconds], ["days", days],
                ["last_day", last_day], ["recent", recent.join(",")],
                ["recent_classes", recent_classes.map { it&.name || UNKNOWN }.join(",")],
                ["goal_streak", streak.current],
                ["longest_goal_streak", streak.longest], ["goal_met_on", streak.last_met]]
      named = records.flat_map { |size_class, each| each.pairs.map { |key, value| ["#{size_class.name}.#{key}", value] } }
      (totals + named).reject { |_, value| value.nil? }.map { |key, value| "#{key}=#{value}\n" }.join
    end

    # The records a game can set on one class of screen: its length, the
    # most dots in a row without a mistake, the fastest pop, and the
    # Longest Time to Pop, with how many +games+ have
    # been played on such screens.
    class Records < Data.define(:games, :longest_game, :most_dots_in_a_row, :shortest_time_to_pop, :longest_time_to_pop)
      def initialize(games: 0, longest_game: 0.0, most_dots_in_a_row: 0, shortest_time_to_pop: nil, longest_time_to_pop: 0.0)
        super(games:, longest_game: longest_game.to_f, most_dots_in_a_row:, shortest_time_to_pop: shortest_time_to_pop&.to_f,
              longest_time_to_pop: longest_time_to_pop.to_f)
      end

      def self.parse(pairs)
        new(games: pairs.count(:games), longest_game: pairs.time(:longest_game) || 0.0,
            most_dots_in_a_row: pairs.count(:most_dots_in_a_row), shortest_time_to_pop: pairs.time(:shortest_time_to_pop),
            longest_time_to_pop: pairs.time(:longest_time_to_pop) || 0.0)
      end

      def add(stats)
        with(games: games + 1, longest_game: [longest_game, stats.duration].max,
             most_dots_in_a_row: [most_dots_in_a_row, stats.most_dots_in_a_row].max,
             shortest_time_to_pop: [shortest_time_to_pop, stats.shortest_time_to_pop].compact.min,
             longest_time_to_pop: [longest_time_to_pop, stats.longest_time_to_pop].max)
      end

      # The records a game with +stats+ would set. A first game sets
      # none, since it has nothing to beat, and neither does a game that
      # only equals a record as the game shows it: whole seconds for a
      # game, tenths for a pop's wait.
      def records_set_by(stats)
        return [] if games.zero?

        [
          (Record.new(kind: :most_dots_in_a_row, value: stats.most_dots_in_a_row) if beats?(stats.most_dots_in_a_row, most_dots_in_a_row, 0)),
          (Record.new(kind: :longest_game, value: stats.duration) if beats?(stats.duration, longest_game, 0)),
          (Record.new(kind: :longest_time_to_pop, value: stats.longest_time_to_pop) if beats?(stats.longest_time_to_pop, longest_time_to_pop, 1)),
          faster(stats.shortest_time_to_pop)
        ].compact
      end

      # The records as +key=value+ pairs, for Stats#to_text.
      def pairs
        [["games", games], ["longest_game", longest_game], ["most_dots_in_a_row", most_dots_in_a_row],
         ["shortest_time_to_pop", shortest_time_to_pop], ["longest_time_to_pop", longest_time_to_pop]]
      end

      private

      # Whether +value+ beats a +record+ that is more than nothing, once both
      # are rounded to +digits+ after the point.
      def beats?(value, record, digits) = record.positive? && value.round(digits) > record.round(digits)

      def faster(pop)
        record = shortest_time_to_pop
        Record.new(kind: :shortest_time_to_pop, value: pop) if pop && record && pop.round(1) < record.round(1)
      end
    end

    # A record a game beat: +kind+ names the stat, +value+ is the game's.
    class Record < Data.define(:kind, :value)
      # The records from most impressive to least. Many dots in a row without a mistake
      # are the game's whole skill, and a long game follows from it; a long
      # wait shows patience, and the fastest pop owes the most to luck.
      ORDER = %i[most_dots_in_a_row longest_game longest_time_to_pop shortest_time_to_pop].freeze
    end

    # The +key=value+ lines of a saved file, read leniently: a value that
    # is missing, negative, or not a number reads as nil (or zero, for a
    # count).
    class Pairs < Data.define(:values)
      def self.parse(text)
        values = text.to_s.lines.filter_map do |line|
          key, value = line.strip.split("=", 2)
          [key.to_s, value.to_s] if value
        end
        new(values: values.to_h)
      end

      def count(key) = natural(values[key.to_s]) || 0

      def time(key)
        number = Float(values[key.to_s].to_s, exception: false)
        number if number&.finite? && !number.negative?
      end

      def counts(key) = values[key.to_s].to_s.split(",").filter_map { natural(it) }

      # The SizeClasses a list names, nil for each it does not know.
      def classes(key) = values[key.to_s].to_s.split(",").map { SizeClass.named(it) }

      def day(key)
        value = values[key.to_s].to_s
        value if DAY.match?(value)
      end

      # The pairs under +prefix+ ("medium.games"), named without it.
      def within(prefix)
        named = "#{prefix}."
        Pairs.new(values: values.filter_map { |key, value| [key.delete_prefix(named), value] if key.start_with?(named) }
                                .to_h)
      end

      private

      def natural(text)
        number = Integer(text.to_s, 10, exception: false)
        number if number && !number.negative?
      end
    end
  end
end
