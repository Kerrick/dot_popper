# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a hint comes and goes: it fades in, stays, and fades out, all
    # within +life+ seconds.
    class HintLook < Data.define(:fade_in, :fade_out, :life); end

    # One line of teaching, shown since +at+. Its +lines+ are one sentence
    # each, so a narrow screen can stack them.
    class Hint < Data.define(:lines, :look, :at)
      def alive?(now) = now - at < look.life

      def alpha(now)
        elapsed = now - at
        return 0.0 unless elapsed.between?(0.0, look.life)

        [elapsed / look.fade_in, (look.life - elapsed) / look.fade_out, 1.0].min
      end
    end

    # Teaches the stacking rule once, the first time ever that the player
    # is penalized, and remembers that it has. It reads and writes through
    # a store that answers +read+ and +write(text)+, as BestScore does.
    class Tutor
      TAUGHT = "taught"

      def initialize(store)
        @store = store
        @taught = store.read.to_s.strip == TAUGHT
      end

      def taught? = @taught

      # The hint for a first wrong tap, or nil once it has been shown.
      def slipped(lines, look, now)
        return if taught?

        @taught = true
        @store.write(TAUGHT)
        Hint.new(lines:, look:, at: now)
      end
    end
  end
end
