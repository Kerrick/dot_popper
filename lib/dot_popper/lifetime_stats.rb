# frozen_string_literal: true

module DotPopper
  # Every round this device has played, added up: the totals (rounds,
  # pops, wrong taps, seconds, and the distinct days played, counted by
  # +last_day+), the bests a round can set (its length, the most pops in
  # a row without a wrong tap, the fastest pop, and the longest wait that
  # still ended in a pop), and the last RECENT scores, oldest first. Days
  # are ISO 8601 dates ("2026-11-05"), local to the player. The best score
  # stays with BestScore. It saves as lines of +key=value+, and reads back
  # whatever it can of a damaged file.
  class LifetimeStats < Data.define(:rounds, :pops, :slips, :seconds, :days, :last_day, :longest_round, :longest_run,
                                    :fastest_pop, :longest_wait, :recent)
    RECENT = 20
    COUNTS = %i[rounds pops slips days longest_run].freeze
    TIMES = %i[seconds longest_round fastest_pop longest_wait].freeze
    DAY = /\A\d{4}-\d{2}-\d{2}\z/

    def initialize(rounds: 0, pops: 0, slips: 0, seconds: 0.0, days: 0, last_day: nil, longest_round: 0.0,
                   longest_run: 0, fastest_pop: nil, longest_wait: 0.0, recent: [])
      super(rounds:, pops:, slips:, seconds: seconds.to_f, days:, last_day:, longest_round: longest_round.to_f,
            longest_run:, fastest_pop: fastest_pop&.to_f, longest_wait: longest_wait.to_f, recent: recent.dup.freeze)
    end

    # The stats read from +text+ as #to_text wrote it. A missing, unknown,
    # or unreadable value keeps its starting value.
    def self.parse(text)
      pairs = Pairs.parse(text)
      new(rounds: pairs.count(:rounds), pops: pairs.count(:pops), slips: pairs.count(:slips),
          seconds: pairs.time(:seconds) || 0.0, days: pairs.count(:days), last_day: pairs.day(:last_day),
          longest_round: pairs.time(:longest_round) || 0.0, longest_run: pairs.count(:longest_run),
          fastest_pop: pairs.time(:fastest_pop), longest_wait: pairs.time(:longest_wait) || 0.0,
          recent: pairs.counts(:recent).last(RECENT))
    end

    # The stats after one more round, played on +day+.
    def add(stats, day:)
      with(rounds: rounds + 1, pops: pops + stats.pops, slips: slips + stats.slips, seconds: seconds + stats.duration,
           days: day == last_day ? days : days + 1, last_day: day,
           longest_round: [longest_round, stats.duration].max, longest_run: [longest_run, stats.longest_run].max,
           fastest_pop: [fastest_pop, stats.fastest_pop].compact.min,
           longest_wait: [longest_wait, stats.longest_wait].max, recent: (recent + [stats.score]).last(RECENT))
    end

    # The records a round with +stats+ would set, most impressive first
    # (Record::ORDER). A first round sets none, since it has nothing to
    # beat, and neither does a round that only equals a best as the game
    # shows it: whole seconds for a round, tenths for a pop's wait.
    def records_set_by(stats)
      return [] if rounds.zero?

      [
        (Record.new(kind: :longest_run, value: stats.longest_run) if beats?(stats.longest_run, longest_run, 0)),
        (Record.new(kind: :longest_round, value: stats.duration) if beats?(stats.duration, longest_round, 0)),
        (Record.new(kind: :longest_wait, value: stats.longest_wait) if beats?(stats.longest_wait, longest_wait, 1)),
        faster(stats.fastest_pop)
      ].compact
    end

    def to_text
      [["rounds", rounds], ["pops", pops], ["slips", slips], ["seconds", seconds], ["days", days],
       ["last_day", last_day], ["longest_round", longest_round], ["longest_run", longest_run],
       ["fastest_pop", fastest_pop], ["longest_wait", longest_wait], ["recent", recent.join(",")]]
        .reject { |_, value| value.nil? }.map { |key, value| "#{key}=#{value}\n" }.join
    end

    private

    # Whether +value+ beats a +best+ that is more than nothing, once both
    # are rounded to +digits+ after the point.
    def beats?(value, best, digits) = best.positive? && value.round(digits) > best.round(digits)

    def faster(pop)
      best = fastest_pop
      Record.new(kind: :fastest_pop, value: pop) if pop && best && pop.round(1) < best.round(1)
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

      def day(key)
        value = values[key.to_s].to_s
        value if DAY.match?(value)
      end

      private

      def natural(text)
        number = Integer(text.to_s, 10, exception: false)
        number if number && !number.negative?
      end
    end
  end
end
