# frozen_string_literal: true

module DotPopper
  # How a round was started, and the seed its dots are drawn from. Each
  # round gets a Random of its own from its seed, and draws from it only
  # when a dot spawns, so the same seed and the same taps give the same
  # dots, whatever else in the game uses randomness meanwhile.
  class Mode < Data.define(:name, :seed)
    LARGEST_SEED = 2_147_483_648 # 2**31

    # A round started the usual way, with a seed drawn from +random+.
    def self.free(random) = new(name: :free, seed: random.rand(LARGEST_SEED))

    def random = Random.new(seed)
  end
end
