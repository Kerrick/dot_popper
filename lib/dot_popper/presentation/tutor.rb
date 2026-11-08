# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the stacking rule is taught: on how many Game Overs, at most, and
    # how its wrong tap replays there, once the score has counted up, then
    # every +every+ seconds, +replays+ times in all.
    class LessonLook < Data.define(:times, :every, :replays)
      # Whether the replay numbered +replayed+ (from 0) is due +since+
      # seconds after the score has counted up.
      def replay_due?(replayed, since) = replayed < replays && since >= replayed * every
    end

    # The wrong tap Game Over teaches from: the popped dot it hit
    # (+popped+, its id) and the bright dot hidden under it (+bright+).
    class Slip < Data.define(:popped, :bright)
      # The slip, if Game Over can still point at it among +dots+ (a
      # Stack): its popped dot is there, and its bright dot is still the
      # bright one. Once that dot was popped, nothing on the pile shows
      # which one it was.
      def among(dots)
        bright = dots.find { it.id == self.bright }
        self if bright&.fresh? && dots.any? { it.id == popped }
      end
    end

    # Teaches the stacking rule on Game Over, with no word, after a round
    # in which the player tapped a popped dot with the bright one hidden
    # beneath it, and never in play: the Show replays that tap's penalty on
    # the pile (Slip). It counts the Game Overs it has taught on, up to
    # +times+, and keeps the count in a store that answers +read+ and
    # +write(text)+, as BestScore does.
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

      # The +lesson+ to give on this Game Over, counting it as given, or
      # nil once one has been given +times+.
      def lesson(lesson)
        return if taught?

        @shown += 1
        @store.write(@shown.to_s)
        lesson
      end
    end
  end
end
