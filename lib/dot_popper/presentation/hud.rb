# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the score and the clock react: +bump+ is a number's scale just
    # after it changes; from +urgent_below+ whole seconds left the clock
    # hurries, and +pulse+ is its scale on each second from then.
    class HudLook < Data.define(:bump, :pulse, :urgent_below); end

    # One number in the HUD as it should be drawn: its small label, its
    # text, its scale (drawn by choosing a bigger font, never by
    # stretching glyphs), and how urgent it is, from 0 (calm) to 1.
    class Readout < Data.define(:label, :text, :scale, :urgency); end

    # The score and the time left, as the player sees them. It notices
    # when either changes, so the number can bump, and when the clock
    # passes a whole second near the end, so it can tick.
    class Hud
      def initialize(look, words)
        @look = look
        @words = words
        reset
      end

      def reset
        @score = @seconds = nil
        @score_changed = @seconds_changed = -Float::INFINITY
        @now = 0.0
      end

      # Reads the round at time +now+. Yields the whole seconds left each
      # time the clock runs down past a second while it is urgent.
      def update(round, now)
        @now = now
        score = round.score
        seconds = [round.countdown.whole_seconds, 0].max
        @score_changed = now if @score && score != @score
        if @seconds && seconds != @seconds
          @seconds_changed = now
          yield seconds if block_given? && seconds < @seconds && seconds.positive? && seconds <= @look.urgent_below
        end
        @score = score
        @seconds = seconds
      end

      def urgent? = !@seconds.nil? && @seconds <= @look.urgent_below

      def score = Readout.new(label: @words.score, text: @score.to_s, scale: @look.bump.at(@now - @score_changed),
                              urgency: 0.0)

      def time
        tween = urgent? ? @look.pulse : @look.bump
        Readout.new(label: @words.time, text: @seconds.to_s, scale: tween.at(@now - @seconds_changed),
                    urgency: urgent? ? 1.0 : 0.0)
      end
    end
  end
end
