# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the score and the clock react: +bump+ is a number's scale just
    # after it changes; from +urgent_below+ whole seconds left the clock
    # hurries, and +pulse+ is its scale on each second from then.
    # +backing+ is the pill's opacity.
    class HudLook < Data.define(:backing, :bump, :pulse, :urgent_below); end

    # One number in the HUD as it should be drawn: its small label, its
    # text, its scale (drawn by choosing a bigger font, never by
    # stretching glyphs), and how urgent it is, from 0 (calm) to 1.
    class Readout < Data.define(:label, :text, :scale, :urgency); end

    # The streak toward a bonus dot, as small dots under the pill: +size+
    # of them, the first +lit+ bright like fresh dots, the rest dark like
    # popped ones, the newest +scale+ big as it bumps. While a bonus dot is
    # on the field (+ready+) all are lit in its mint, the streak cashed in
    # as the dot to pop.
    class Streak < Data.define(:lit, :size, :ready, :scale)
      def lit?(index) = ready || index < lit
      def bumping?(index) = !ready && index == lit - 1
    end

    # The score and the time left as the player last saw them, and when
    # each last changed, so a number can bump and the clock can tick. The
    # streak (+streak+ pops in a row of +size+ that earn a bonus dot, or
    # nil before the tutorial's streak beat and where there is no bonus) works the same way,
    # and +ready+ says a bonus dot is on the field.
    class Hud < Data.define(:look, :words, :score, :seconds, :streak, :size, :ready, :score_changed, :seconds_changed,
                            :streak_changed, :now)
      # A streak dot's radius as a share of the pill's height, and the
      # distance between two, in their radii.
      PIP = 0.11
      PIP_STEP = 2.8

      def self.blank(look, words)
        new(look:, words:, score: nil, seconds: nil, streak: nil, size: nil, ready: false,
            score_changed: -Float::INFINITY, seconds_changed: -Float::INFINITY, streak_changed: -Float::INFINITY,
            now: 0.0)
      end

      # The HUD after reading +round+ at time +now+. Yields the whole
      # seconds left when the clock runs down past a second while urgent.
      def read(round, now)
        score = round.score
        seconds = [round.countdown.whole_seconds, 0].max
        if self.seconds && seconds < self.seconds && seconds.positive? && seconds <= look.urgent_below && block_given?
          yield seconds
        end
        showing(score, seconds, now).streaking(round, now)
      end

      # The HUD showing +round+'s streak at time +now+; a streak that grew
      # bumps its newest dot.
      def streaking(round, now)
        return with(streak: nil, size: nil, ready: false) unless round.bonus && !round.over?

        streak = round.streak
        ready = round.dots.any? { it.fresh? && it.bonus? }
        grew = self.streak && streak > self.streak
        with(streak:, size: round.bonus.streak, ready:, streak_changed: grew ? now : streak_changed)
      end

      # The streak's small dots as they should be drawn, or nil without one.
      def streak_readout
        return unless streak

        Streak.new(lit: streak, size:, ready:, scale: look.bump.at(now - streak_changed))
      end

      # The HUD showing +lit+ of a streak of +size+, the row all mint when
      # +ready+, as the Tutorial's rehearsal sets it; a dot newly lit bumps.
      def counting(lit, size, ready, now)
        with(streak: lit, size:, ready:, streak_changed: streak && lit > streak ? now : streak_changed)
      end

      # The HUD showing +score+ and +seconds+ at time +now+, as the Tutorial
      # sets them; a number that changed bumps.
      def showing(score, seconds, now)
        with(score:, seconds:, now:,
             score_changed: self.score && score != self.score ? now : score_changed,
             seconds_changed: self.seconds && seconds != self.seconds ? now : seconds_changed)
      end

      # How tall the HUD's pill is around a number line +number+ tall and
      # a label line +label+ tall.
      def self.height(number, label) = label + (number * 0.9) + padding(number)

      # The pill's padding around a number line +number+ tall.
      def self.padding(number) = number * 0.28

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
