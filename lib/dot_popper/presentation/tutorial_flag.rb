# frozen_string_literal: true

module DotPopper
  module Presentation
    # Whether the first Play opens the Tutorial. It does once, on a fresh
    # install, and never again: the store, which answers +read+ and
    # +write(text)+ as ScoreRecord's does, keeps that it was seen, apart from
    # the records, so clearing them leaves it. A player who has played
    # before, as everyone on 0.9 has, has seen enough of the game already,
    # so the tutorial is never due for them either (#due?).
    #
    # +mode+ is :usual, :skipped (never, for the bot and the GUI suite), or
    # :forced (on every Play, to try it out), as TutorialFlag.mode reads
    # them from the environment.
    class TutorialFlag
      SEEN = "seen"
      SKIPPED_BY = %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_TUTORIAL].freeze
      FORCED_BY = "DOT_POPPER_TUTORIAL"

      # A flag that is never due, for a Show that teaches nothing.
      def self.never = new(ScoreRecord::Memory.new, mode: :skipped)

      # The mode +env+ asks for: DOT_POPPER_TUTORIAL=1 forces it, and the
      # bot, the GUI director and DOT_POPPER_NO_TUTORIAL leave it out.
      def self.mode(env)
        return :forced if env.fetch(FORCED_BY, "") == "1"
        return :skipped if SKIPPED_BY.any? { !env.fetch(it, "").empty? }

        :usual
      end

      attr_reader :mode

      def initialize(store, mode: :usual)
        @store = store
        @mode = mode
      end

      # Whether the tutorial has been seen on this device.
      def seen? = @store.read.to_s.strip == SEEN

      # Whether this Play should open the tutorial, for a player who has
      # +played+ a game before or not.
      def due?(played:)
        case mode
        in :forced then true
        in :skipped then false
        in :usual then !seen? && !played
        end
      end

      # The tutorial opened: it is seen from now on.
      def seen! = (@store.write(SEEN) unless seen?)
    end
  end
end
