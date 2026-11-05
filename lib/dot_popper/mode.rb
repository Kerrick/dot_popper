# frozen_string_literal: true

require "date"

module DotPopper
  # How a round was started, and the seed its dots are drawn from. Each
  # round gets a Random of its own from its seed, and draws from it only
  # when a dot spawns, so the same seed and the same taps give the same
  # dots, whatever else in the game uses randomness meanwhile.
  #
  # A free round is the usual one. A daily round's seed comes from its
  # local calendar +date+, so everyone who plays that day's Daily gets
  # the same dots in the same order.
  class Mode < Data.define(:name, :seed, :date)
    LARGEST_SEED = 2_147_483_648 # 2**31

    # A round started the usual way, with a seed drawn from +random+.
    def self.free(random) = new(name: :free, seed: random.rand(LARGEST_SEED), date: nil)

    def self.daily(date) = new(name: :daily, seed: seed_for(date), date:)

    # The day's seed: FNV-1a of its YYYYMMDD digits, which, unlike
    # String#hash, is the same in every process, on every machine.
    def self.seed_for(date)
      digits = format("%04d%02d%02d", date.year, date.month, date.day)
      hash = digits.each_byte.reduce(0x811c9dc5) { |sum, byte| ((sum ^ byte) * 0x01000193) & 0xffffffff }
      hash % LARGEST_SEED
    end

    def daily? = name == :daily

    def random = Random.new(seed)
  end
end
