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

    # The score and the time left as the player last saw them, and when
    # each last changed, so a number can bump and the clock can tick.
    class Hud < Data.define(:look, :words, :score, :seconds, :score_changed, :seconds_changed, :now)
      def self.blank(look, words)
        new(look:, words:, score: nil, seconds: nil, score_changed: -Float::INFINITY,
            seconds_changed: -Float::INFINITY, now: 0.0)
      end

      # The HUD after reading +round+ at time +now+. Yields the whole
      # seconds left when the clock runs down past a second while urgent.
      def read(round, now)
        score = round.score
        seconds = [round.countdown.whole_seconds, 0].max
        if self.seconds && seconds < self.seconds && seconds.positive? && seconds <= look.urgent_below && block_given?
          yield seconds
        end
        with(score:, seconds:, now:,
             score_changed: self.score && score != self.score ? now : score_changed,
             seconds_changed: self.seconds && seconds != self.seconds ? now : seconds_changed)
      end

      def urgent? = !seconds.nil? && seconds <= look.urgent_below

      def score_readout
        Readout.new(label: words.score, text: score.to_s, scale: look.bump.at(now - score_changed), urgency: 0.0)
      end

      def time_readout
        tween = urgent? ? look.pulse : look.bump
        Readout.new(label: words.time, text: seconds.to_s, scale: tween.at(now - seconds_changed),
                    urgency: urgent? ? 1.0 : 0.0)
      end
    end
  end
end
