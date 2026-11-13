# frozen_string_literal: true

module DotPopper
  # One day's goal, met or not by a single game's GameStats: +kind+
  # names what it asks for, and +target+ how much. Each local date picks
  # one from LIST with a hash of the date that is the same on every
  # device and every run, so the day's goal never changes while the day
  # lasts. Each player is judged only by their own play, so the goal
  # needs no comparison between screens. The words for each are Presentation's.
  class DailyGoal < Data.define(:kind, :target)
    # The goals, each a thing a single game can do. The targets were set
    # with the simulator's model player on the 24 × 16 R window (see
    # doc/design/progress.md): reachable on a good game, not on every game.
    # The bonus dot (Rules::BONUS) lengthens games and raises scores, and
    # the three targets that count those were raised to match.
    LIST = [
      new(kind: :clean_run, target: 15),   # dots in a row without a mistake
      new(kind: :patient_pop, target: 3),  # seconds a bright dot was on screen before its pop
      new(kind: :quick_start, target: 10), # dots popped in the game's first 10 seconds
      new(kind: :long_game, target: 50),  # seconds the game lasts
      new(kind: :comeback, target: 30),    # points, in a game with a mistake
      new(kind: :score, target: 30),       # points
      new(kind: :clean_game, target: 10)  # points, with no mistake at all
    ].freeze

    QUICK_START_SECONDS = 10

    # The goal for +date+.
    def self.for(date) = LIST.fetch(fnv(date.iso8601) % LIST.size)

    # A 32-bit FNV-1a hash of +text+: small, and the same everywhere,
    # unlike String#hash, which changes from run to run.
    def self.fnv(text)
      text.each_byte.reduce(0x811c9dc5) { |hash, byte| ((hash ^ byte) * 0x01000193) & 0xffffffff }
    end

    # Whether a game with +stats+ meets the goal.
    def met?(stats)
      case kind
      when :clean_run then stats.most_dots_in_a_row >= target
      when :patient_pop then stats.longest_time_to_pop >= target
      when :quick_start then stats.dots_popped_within(QUICK_START_SECONDS) >= target
      when :long_game then stats.duration >= target
      when :comeback then stats.mistakes.positive? && stats.score >= target
      when :score then stats.score >= target
      when :clean_game then stats.mistakes.zero? && stats.score >= target
      else false
      end
    end

    # The goal as the playtest log names it: "clean_run_15".
    def to_s = "#{kind}_#{target}"
  end
end
