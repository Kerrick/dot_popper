# frozen_string_literal: true

module DotPopper
  # The highest score on this device. It reads and writes through a store
  # that answers +read+ and +write(text)+, so the rules never touch a file
  # system themselves (Lota's save folder in the game, memory in tests).
  class BestScore
    attr_reader :value

    def initialize(store)
      @store = store
      @value = Integer(store.read.to_s.strip, exception: false) || 0
    end

    # Records +score+ and says whether it beat the previous best.
    def record(score)
      return false unless score > value

      @value = score
      @store.write(score.to_s)
      true
    end

    # A store that keeps the score in memory, for tests and for a device
    # whose save folder cannot be written.
    class Memory
      def initialize(text = nil) = @text = text
      def read = @text
      def write(text) = @text = text
    end
  end
end
