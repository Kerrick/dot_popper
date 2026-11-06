# frozen_string_literal: true

module DotPopper
  module Presentation
    # setdef's logotype, the maker's mark, shown before the title: the
    # word "setdef" in Iosevka Bold, then a solid block like a text
    # cursor. All its measures are fractions of +size+, the font's size
    # (an em), taken from setdef's own artwork, where the letters' x-height
    # is the unit; the block is as wide and tall as that artwork has it.
    class Logotype < Data.define(:size)
      WORD = "setdef"
      XHEIGHT = 0.52 # Iosevka's, in an em
      ADVANCE = 0.46 # a letter's step, a little tighter than Iosevka's 0.5
      BLOCK_GAP = 0.16 * XHEIGHT # past the last letter's cell
      BLOCK_WIDTH = 1.03 * XHEIGHT
      BLOCK_TOP = -1.57 * XHEIGHT # from the baseline, down being positive
      BLOCK_BOTTOM = 0.21 * XHEIGHT
      WIDTH = (WORD.length * ADVANCE) + BLOCK_GAP + BLOCK_WIDTH # in ems
      GLOW = 0.14 * XHEIGHT # how far the letters' glow reaches, in ems

      # The size that fits a window +width+ by +height+: about as wide as
      # setdef's artwork is in its frame, narrower on a portrait screen,
      # and never more than 60% of the height. Whole units.
      def self.fit(width, height)
        across = width * (height > width ? 0.7 : 0.78)
        tall = height * 0.6 / (BLOCK_BOTTOM - BLOCK_TOP)
        new(size: [[across / WIDTH, tall].min.floor, 1].max)
      end

      def width = WIDTH * size
      def left(center_x) = center_x - (width / 2.0)

      # The baseline's place, which puts the block's middle at +center_y+.
      def baseline(center_y) = center_y - ((BLOCK_TOP + BLOCK_BOTTOM) / 2.0 * size)

      # Where each letter of "setdef" starts, from +left+.
      def letters(left) = WORD.each_char.with_index.map { |char, i| [char, left + (i * ADVANCE * size)] }

      # The block's left edge and its width, then its top (from the
      # +baseline+) and its height.
      def block(left) = [left + (((WORD.length * ADVANCE) + BLOCK_GAP) * size), BLOCK_WIDTH * size]
      def block_top(baseline) = baseline + (BLOCK_TOP * size)
      def block_height = (BLOCK_BOTTOM - BLOCK_TOP) * size
    end

    # How the setdef splash plays: it fades in, holds, and fades out, and
    # a press ends it. It makes no sound. +at+ is the seconds since it began.
    class Splash < Data.define(:at)
      FADE_IN = 0.25
      HOLD = 0.85
      FADE_OUT = 0.3
      TOTAL = FADE_IN + HOLD + FADE_OUT
      SKIPPED_BY = %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_SPLASH].freeze

      def self.start = new(at: 0.0)

      # Whether the environment (+env+) asks for no splash: the bot, the GUI
      # director, and a plain request leave it out.
      def self.skipped?(env) = SKIPPED_BY.any? { !env.fetch(it, "").empty? }

      def advance(seconds) = with(at: at + seconds)
      def skip = with(at: TOTAL)
      def over? = at >= TOTAL

      # How much of the mark shows, 0 to 1.
      def mark = at < FADE_IN ? at / FADE_IN : fade_out

      # How much of the black ground shows: all of it until the fade out,
      # which shows the title under it.
      def ground = fade_out

      private

      def fade_out = ((TOTAL - at) / FADE_OUT).clamp(0.0, 1.0)
    end
  end
end
