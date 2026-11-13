# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the score and the clock react: +bump+ is a number's scale just
    # after it changes; from +urgent_below+ whole seconds left the clock
    # hurries, and +pulse+ is its scale on each second from then.
    # +backing+ is the pill's opacity.
    class HudStyle < Data.define(:backing, :bump, :pulse, :urgent_below); end

    # One number in the HUD as it should be drawn: its small label, its
    # text, its scale (drawn by choosing a bigger font, never by
    # stretching glyphs), and how urgent it is, from 0 (calm) to 1.
    class Readout < Data.define(:label, :text, :scale, :urgency); end

    # The row toward a bonus dot, as small dots under the pill: +size+
    # of them, the first +lit+ light like bright dots, the rest dark like
    # popped ones, the newest +scale+ big as it bumps. While a bonus dot is
    # on the field (+ready+) all are lit in its mint, the row cashed in
    # as the dot to pop.
    class DotsInARow < Data.define(:lit, :size, :ready, :scale)
      def lit?(index) = ready || index < lit
      def bumping?(index) = !ready && index == lit - 1
    end

    # Where the HUD's parts go on +layout+, for the readouts' words: the
    # numbers' and labels' type sizes and line heights, the pill's padding
    # and +height+, and +cell+, each readout's half of the pill, wide
    # enough for its widest text (its number, "00" or its label). The pill
    # is centered on +center_x+ from +top+.
    class HudPlan < Data.define(:number_size, :label_size, :number_height, :label_height, :pad, :cell, :height, :center_x, :top)
      def self.for(readouts, layout:, type:, measure:)
        number_size = layout.scaled(type.hud_number)
        label_size = layout.scaled(type.hud_label)
        number = measure.height(:bold, number_size)
        label = measure.height(:semibold, label_size)
        pad = Hud.padding(number)
        widest = readouts.map do |readout|
          [measure.width(:bold, number_size, readout.text), measure.width(:bold, number_size, "00"),
           measure.width(:semibold, label_size, readout.label)].max
        end
        new(number_size:, label_size:, number_height: number, label_height: label, pad:, cell: widest.max + (pad * 2.4),
            height: Hud.height(number, label), center_x: layout.center_x, top: layout.top)
      end
    end

    # Everything Shell::HudPainter draws: its +plan+ (HudPlan), the score's
    # and the time's Readouts, the type size each number is drawn at as it
    # bumps (+sizes+), and the row toward a bonus dot (DotsInARow, or nil).
    class HudDrawing < Data.define(:plan, :readouts, :sizes, :dots_in_a_row); end

    # Makes the HUD's drawing for each frame, laying it out again only when
    # the window, the type's scale (+scale+, the screen's density) or the
    # readouts' words change.
    class HudDrawings
      def initialize(type:, measure:)
        @type = type
        @measure = measure
        @plan = Memo.new
      end

      def call(hud, layout, scale)
        readouts = [hud.score_readout, hud.time_readout]
        key = [layout, scale, *readouts.flat_map { [it.text, it.label] }]
        plan = @plan.fetch(key) { HudPlan.for(readouts, layout:, type: @type, measure: @measure) }
        sizes = readouts.map { Pixels.font_size(plan.number_size * it.scale, step: Hud::BUMP_STEP) }
        HudDrawing.new(plan:, readouts:, sizes:, dots_in_a_row: hud.dots_in_a_row_readout)
      end
    end

    # The score and the time left as the player last saw them, and when
    # each last changed, so a number can bump and the clock can tick. The
    # row (+row+ dots in a row of +size+ that earn a bonus dot, or
    # nil where there is no bonus) works the same way,
    # and +ready+ says a bonus dot is on the field.
    class Hud < Data.define(:style, :words, :score, :seconds, :dots_in_a_row, :size, :ready, :score_changed, :seconds_changed,
                            :dots_in_a_row_changed, :now)
      # A row dot's radius as a share of the pill's height, and the
      # distance between two, in their radii.
      PIP = 0.11
      PIP_STEP = 2.8
      # The type sizes a number steps through as it bumps, in graphics units.
      BUMP_STEP = 2

      def self.blank(style, words)
        new(style:, words:, score: nil, seconds: nil, dots_in_a_row: nil, size: nil, ready: false,
            score_changed: -Float::INFINITY, seconds_changed: -Float::INFINITY, dots_in_a_row_changed: -Float::INFINITY,
            now: 0.0)
      end

      # The HUD after reading +game+ at time +now+. Yields the whole
      # seconds left when the clock runs down past a second while urgent.
      def read(game, now)
        score = game.score
        seconds = [game.countdown.whole_seconds, 0].max
        if self.seconds && seconds < self.seconds && seconds.positive? && seconds <= style.urgent_below && block_given?
          yield seconds
        end
        showing(score, seconds, now).tracking_row(game, now)
      end

      # The HUD showing +game+'s row at time +now+; a row that grew
      # bumps its newest dot.
      def tracking_row(game, now)
        return with(dots_in_a_row: nil, size: nil, ready: false) unless game.bonus && !game.over?

        dots_in_a_row = game.dots_in_a_row
        ready = game.dots.any? { it.bright? && it.bonus? }
        grew = self.dots_in_a_row && dots_in_a_row > self.dots_in_a_row
        with(dots_in_a_row:, size: game.bonus.dots_in_a_row, ready:, dots_in_a_row_changed: grew ? now : dots_in_a_row_changed)
      end

      # The row's small dots as they should be drawn, or nil without one.
      def dots_in_a_row_readout
        return unless dots_in_a_row

        DotsInARow.new(lit: dots_in_a_row, size:, ready:, scale: style.bump.at(now - dots_in_a_row_changed))
      end

      # The HUD showing +lit+ of a row of +size+, as the Tutorial sets it;
      # a dot newly lit bumps.
      def counting(lit, size, now)
        with(dots_in_a_row: lit, size:, ready: false, dots_in_a_row_changed: dots_in_a_row && lit > dots_in_a_row ? now : dots_in_a_row_changed)
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

      def urgent? = !seconds.nil? && seconds <= style.urgent_below

      def score_readout
        Readout.new(label: words.score, text: score.to_s, scale: style.bump.at(now - score_changed), urgency: 0.0)
      end

      def time_readout
        tween = urgent? ? style.pulse : style.bump
        Readout.new(label: words.time, text: seconds.to_s, scale: tween.at(now - seconds_changed),
                    urgency: urgent? ? 1.0 : 0.0)
      end
    end
  end
end
