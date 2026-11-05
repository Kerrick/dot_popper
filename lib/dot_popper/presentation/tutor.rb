# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the stacking rule is taught: on how many Game Overs, at most,
    # how strongly its lines show, and how far "Time's up!" moves down to
    # make room for them, as a part of the safe area's height.
    class LessonLook < Data.define(:times, :alpha, :room); end

    # Teaches the stacking rule on Game Over, after a round in which the
    # player tapped a popped dot with the bright one hidden beneath it,
    # and never in play, where nobody stops to read. It counts the Game
    # Overs it has taught on, up to +times+, and keeps the count in a
    # store that answers +read+ and +write(text)+, as BestScore does.
    class Tutor
      # What an older version saved once it had shown its hint, in play.
      # A player who saw that has been taught.
      LEGACY = "taught"

      def initialize(store, times:)
        @store = store
        @times = times
        saved = store.read.to_s.strip
        @shown = saved == LEGACY ? times : Integer(saved, exception: false) || 0
      end

      attr_reader :shown

      def taught? = shown >= @times

      # The +lines+ to show on this Game Over, counting them as shown, or
      # nil once they have been shown +times+.
      def lesson(lines)
        return if taught?

        @shown += 1
        @store.write(@shown.to_s)
        lines
      end
    end
  end
end
