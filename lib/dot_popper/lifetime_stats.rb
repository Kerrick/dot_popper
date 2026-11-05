# frozen_string_literal: true

module DotPopper
  # Every round this device has played, added up: the totals (rounds,
  # pops, wrong taps, seconds, and the distinct days played, counted by
  # +last_day+), the last RECENT scores, oldest first, with the SizeClass
  # each was played in (+recent_classes+, nil where a file written before
  # they were kept does not say), and the daily goal's GoalStreak, across
  # every screen; and for each SizeClass, the
  # Bests a round on such a screen can set. Days are ISO 8601 dates
  # ("2026-11-05"), local to the player. The best score stays with
  # BestScore. It saves as lines of +key=value+, a class's bests under
  # its name ("medium.longest_run=18"), and reads back whatever it can of
  # a damaged file.
  class LifetimeStats < Data.define(:rounds, :pops, :slips, :seconds, :days, :last_day, :recent, :recent_classes,
                                    :streak, :bests)
    RECENT = 20
    DAY = /\A\d{4}-\d{2}-\d{2}\z/
    UNKNOWN = "?" # a recent score's class, in a file written before they were kept

    # +recent_classes+ line up with +recent+ from the newest back; a score
    # with none is of an unknown class.
    def initialize(rounds: 0, pops: 0, slips: 0, seconds: 0.0, days: 0, last_day: nil, recent: [], recent_classes: [],
                   streak: GoalStreak.new, bests: {})
      classes = ([nil] * recent.size) + recent_classes
      super(rounds:, pops:, slips:, seconds: seconds.to_f, days:, last_day:, recent: recent.dup.freeze,
            recent_classes: classes.last(recent.size).freeze, streak:, bests: bests.dup.freeze)
    end

    # The stats read from +text+ as #to_text wrote it. A missing, unknown,
    # or unreadable value keeps its starting value. A file written before
    # bests were kept by class has them unnamed; they go to +legacy+, the
    # class of the screen the game opens on (see .old?).
    def self.parse(text, legacy: SizeClass::MEDIUM)
      pairs = Pairs.parse(text)
      bests = SizeClass::ALL.to_h { [it, Bests.parse(pairs.within(it.name))] }
      bests[legacy] = Bests.parse(pairs) if old?(text)
      new(rounds: pairs.count(:rounds), pops: pairs.count(:pops), slips: pairs.count(:slips),
          seconds: pairs.time(:seconds) || 0.0, days: pairs.count(:days), last_day: pairs.day(:last_day),
          recent: pairs.counts(:recent).last(RECENT), recent_classes: pairs.classes(:recent_classes).last(RECENT),
          streak: GoalStreak.new(current: pairs.count(:goal_streak), longest: pairs.count(:longest_goal_streak),
                                 last_met: pairs.day(:goal_met_on)),
          bests: bests.reject { |_, each| each.rounds.zero? })
    end

    # Whether +text+ keeps its bests unnamed, as files did before they
    # were kept by class.
    def self.old?(text) = Pairs.parse(text).values.key?("longest_round")

    # The bests on screens of +size_class+, or none yet.
    def bests_in(size_class) = bests.fetch(size_class) { Bests.new }

    # The stats after one more round, played on +day+ on a screen of
    # +size_class+.
    def add(stats, day:, size_class:)
      with(rounds: rounds + 1, pops: pops + stats.pops, slips: slips + stats.slips, seconds: seconds + stats.duration,
           days: day == last_day ? days : days + 1, last_day: day, recent: (recent + [stats.score]).last(RECENT),
           recent_classes: (recent_classes + [size_class]).last(RECENT),
           bests: bests.merge(size_class => bests_in(size_class).add(stats)))
    end

    # The records a round with +stats+ on a screen of +size_class+ would
    # set, most impressive first (Record::ORDER); see Bests#records_set_by.
    def records_set_by(stats, size_class) = bests_in(size_class).records_set_by(stats)

    def to_text
      totals = [["rounds", rounds], ["pops", pops], ["slips", slips], ["seconds", seconds], ["days", days],
                ["last_day", last_day], ["recent", recent.join(",")],
                ["recent_classes", recent_classes.map { it&.name || UNKNOWN }.join(",")],
                ["goal_streak", streak.current],
                ["longest_goal_streak", streak.longest], ["goal_met_on", streak.last_met]]
      named = bests.flat_map { |size_class, each| each.pairs.map { |key, value| ["#{size_class.name}.#{key}", value] } }
      (totals + named).reject { |_, value| value.nil? }.map { |key, value| "#{key}=#{value}\n" }.join
    end

    # The bests a round can set on one class of screen: its length, the
    # most pops in a row without a wrong tap, the fastest pop, and the
    # longest wait that still ended in a pop, with how many +rounds+ have
    # been played on such screens.
    class Bests < Data.define(:rounds, :longest_round, :longest_run, :fastest_pop, :longest_wait)
      def initialize(rounds: 0, longest_round: 0.0, longest_run: 0, fastest_pop: nil, longest_wait: 0.0)
        super(rounds:, longest_round: longest_round.to_f, longest_run:, fastest_pop: fastest_pop&.to_f,
              longest_wait: longest_wait.to_f)
      end

      def self.parse(pairs)
        new(rounds: pairs.count(:rounds), longest_round: pairs.time(:longest_round) || 0.0,
            longest_run: pairs.count(:longest_run), fastest_pop: pairs.time(:fastest_pop),
            longest_wait: pairs.time(:longest_wait) || 0.0)
      end

      def add(stats)
        with(rounds: rounds + 1, longest_round: [longest_round, stats.duration].max,
             longest_run: [longest_run, stats.longest_run].max,
             fastest_pop: [fastest_pop, stats.fastest_pop].compact.min,
             longest_wait: [longest_wait, stats.longest_wait].max)
      end

      # The records a round with +stats+ would set. A first round sets
      # none, since it has nothing to beat, and neither does a round that
      # only equals a best as the game shows it: whole seconds for a
      # round, tenths for a pop's wait.
      def records_set_by(stats)
        return [] if rounds.zero?

        [
          (Record.new(kind: :longest_run, value: stats.longest_run) if beats?(stats.longest_run, longest_run, 0)),
          (Record.new(kind: :longest_round, value: stats.duration) if beats?(stats.duration, longest_round, 0)),
          (Record.new(kind: :longest_wait, value: stats.longest_wait) if beats?(stats.longest_wait, longest_wait, 1)),
          faster(stats.fastest_pop)
        ].compact
      end

      # The bests as +key=value+ pairs, for LifetimeStats#to_text.
      def pairs
        [["rounds", rounds], ["longest_round", longest_round], ["longest_run", longest_run],
         ["fastest_pop", fastest_pop], ["longest_wait", longest_wait]]
      end

      private

      # Whether +value+ beats a +best+ that is more than nothing, once both
      # are rounded to +digits+ after the point.
      def beats?(value, best, digits) = best.positive? && value.round(digits) > best.round(digits)

      def faster(pop)
        best = fastest_pop
        Record.new(kind: :fastest_pop, value: pop) if pop && best && pop.round(1) < best.round(1)
      end
    end

    # A best a round beat: +kind+ names the stat, +value+ is the round's.
    class Record < Data.define(:kind, :value)
      # The records from most impressive to least. A long run of clean pops
      # is the game's whole skill, and a long round follows from it; a long
      # wait shows patience, and the fastest pop owes the most to luck.
      ORDER = %i[longest_run longest_round longest_wait fastest_pop].freeze
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

      # The pairs under +prefix+ ("medium.rounds"), named without it.
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
