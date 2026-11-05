# frozen_string_literal: true

module DotPopper
  # One day's goal, met or not by a single round's RoundStats: +kind+
  # names what it asks for, and +target+ how much. Each local date picks
  # one from LIST with a hash of the date that is the same on every
  # device and every run, so the day's goal never changes while the day
  # lasts. Each player is judged only by their own play, so the goal is
  # fair whatever the screen. The words for each are Presentation's.
  class DailyGoal < Data.define(:kind, :target)
    # The goals, each a thing a single round can do. The targets were set
    # with the simulator's model player on the 24 × 16 R window (see
    # doc/decisions.md): reachable on a good round, not on every round.
    LIST = [
      new(kind: :clean_run, target: 15),   # pops in a row without a wrong tap
      new(kind: :patient_pop, target: 3),  # seconds a fresh dot was on screen before its pop
      new(kind: :quick_start, target: 10), # pops in the round's first 10 seconds
      new(kind: :long_round, target: 40),  # seconds the round lasts
      new(kind: :comeback, target: 20),    # points, in a round with a wrong tap
      new(kind: :score, target: 25),       # points
      new(kind: :clean_round, target: 10)  # points, with no wrong tap at all
    ].freeze

    QUICK_START_SECONDS = 10

    # The goal for +date+.
    def self.for(date) = LIST.fetch(fnv(date.iso8601) % LIST.size)

    # A 32-bit FNV-1a hash of +text+: small, and the same everywhere,
    # unlike String#hash, which changes from run to run.
    def self.fnv(text)
      text.each_byte.reduce(0x811c9dc5) { |hash, byte| ((hash ^ byte) * 0x01000193) & 0xffffffff }
    end

    # Whether a round with +stats+ meets the goal.
    def met?(stats)
      case kind
      when :clean_run then stats.longest_run >= target
      when :patient_pop then stats.longest_wait >= target
      when :quick_start then stats.pops_within(QUICK_START_SECONDS) >= target
      when :long_round then stats.duration >= target
      when :comeback then stats.slips.positive? && stats.score >= target
      when :score then stats.score >= target
      when :clean_round then stats.slips.zero? && stats.score >= target
      else false
      end
    end

    # The goal as the playtest log names it: "clean_run_15".
    def to_s = "#{kind}_#{target}"
  end
end
