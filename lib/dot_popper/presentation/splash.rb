# frozen_string_literal: true

module DotPopper
  module Presentation
    # setdef's logotype, the maker's mark, shown before the title: the
    # word "setdef" in Iosevka Bold, then a solid block like a text
    # cursor. All its measures are ems of +size+, the font's size. The
    # block's are the maintainer's decision (doc/decisions.md): one
    # Iosevka cell wide, 0.95em tall, from 0.14em below the baseline to
    # 0.81em above it, and 0.5em / 7 past the end of the "f"'s cell.
    class Logotype < Data.define(:size)
      WORD = "setdef"
      CELL = 0.5 # Iosevka's cell, an em's half
      ADVANCE = CELL # a letter's step: Iosevka's own, no tracking
      BLOCK_GAP = CELL / 7 # from the end of the last letter's full cell
      BLOCK_WIDTH = CELL
      BLOCK_TOP = -0.81 # from the baseline, down being positive
      BLOCK_BOTTOM = 0.14
      BLOCK_LEFT = ((WORD.length - 1) * ADVANCE) + CELL + BLOCK_GAP # from the first letter's start
      WIDTH = BLOCK_LEFT + BLOCK_WIDTH # in ems
      # setdef's glow (brand/README.md): the mark blurred, in its own
      # colour at 55%, under the mark. The spec calls it "a blur of
      # 0.12em"; the artwork's filter is a Gaussian with a standard
      # deviation of 60 of Iosevka's 1000 units, 0.06em, which is what
      # the screen matches.
      GLOW_SIGMA = 0.06
      GLOW_STRENGTH = 0.55
      GLOW_PASSES = 3
      GLOW_STEP = 3.0 # the blur's sigma per pass, in the blurred layer's pixels

      # The size that fits a window +width+ by +height+: about as wide as
      # setdef's artwork is in its frame, narrower on a portrait screen,
      # and never more than 60% of the height. Whole units.
      def self.fit(width, height)
        across = width * (height > width ? 0.7 : 0.78)
        tall = height * 0.6 / (BLOCK_BOTTOM - BLOCK_TOP)
        new(size: [[across / WIDTH, tall].min.floor, 1].max)
      end

      # The Bloom's look that blurs the mark by GLOW_SIGMA of its size,
      # in device pixels, at every size. The blur runs +GLOW_PASSES+ times
      # at GLOW_STEP, whose nine taps spread (BlurKernel.spread) a little
      # less than the sigma says; over the passes that adds up to a number
      # of blurred pixels, and the blurred layer's +resolution+ is what
      # makes that the wanted number of device pixels. A mark small enough
      # to need more than the full resolution is blurred more gently
      # instead. The size is in graphics units, so +density+ is the device
      # pixels to each.
      def glow(density = 1.0)
        wanted = GLOW_SIGMA * size * density
        reach = BlurKernel.spread(GLOW_STEP) * Math.sqrt(GLOW_PASSES)
        resolution = [reach / wanted, 1.0].min
        sigma = BlurKernel.sigma_for(wanted * resolution / Math.sqrt(GLOW_PASSES))
        BloomLook.new(strength: GLOW_STRENGTH, sigma:, passes: GLOW_PASSES, resolution:)
      end

      def width = WIDTH * size
      def left(center_x) = center_x - (width / 2.0)

      # The baseline's place, which puts the block's middle at +center_y+.
      def baseline(center_y) = center_y - ((BLOCK_TOP + BLOCK_BOTTOM) / 2.0 * size)

      # Where each letter of "setdef" starts, from +left+.
      def letters(left) = WORD.each_char.with_index.map { |char, i| [char, left + (i * ADVANCE * size)] }

      # The block's left edge and its width, then its top (from the
      # +baseline+) and its height.
      def block(left) = [left + (BLOCK_LEFT * size), BLOCK_WIDTH * size]
      def block_top(baseline) = baseline + (BLOCK_TOP * size)
      def block_height = (BLOCK_BOTTOM - BLOCK_TOP) * size
    end

    # How the setdef splash plays: it fades in, holds, and fades out, and
    # a press ends it. Over it plays a jingle: the clicks of pressing
    # Bigger, Smaller, Bigger, Smaller, "Your records", and Back, at 120
    # beats a minute, in quarter, quarter, a quarter's rest, eighth,
    # eighth, quarter, quarter. The rhythm says when each click starts, not
    # how long it lasts. It goes high, low, high, low, then middle and lower:
    # Bigger is the high click and Smaller the low one, as they sound on a
    # computer, whichever dot size each names on the screen at hand, and the
    # last two are those buttons' own clicks. Only while the game's sound is on
    # (+sounding+) does it play, and the splash lasts until it has rung;
    # muted, the splash is short. +at+ is the seconds since it began.
    #
    # The block blinks like an amber terminal's cursor, lighting quickly
    # and fading a little slower, as a phosphor does. Sounding, each note
    # flips it: lit from the first until the second, dark until the third,
    # and so on, so the last note leaves it dark, and it holds dark for a
    # beat before the fade out, so that the fade to the title is not
    # mistaken for the cursor fading: the splash stays that long. Muted,
    # there is no music to flash to, so the block stays lit. So it does
    # when +calm+ (DOT_POPPER_CALM, the reduced-motion setting), as setdef's
    # brand says a blinking mark stops under reduced motion; the jingle
    # still plays, if sound is on.
    class Splash < Data.define(:at, :sounding, :calm)
      BEAT = 60.0 / 120
      Note = Data.define(:at, :pitch)
      JINGLE = [[0.0, 1.2], [1.0, 0.9], [3.0, 1.2], [3.5, 0.9], [4.0, 1.0], [5.0, 0.8]]
               .map { |beat, pitch| Note.new(at: beat * BEAT, pitch:) }.freeze
      FADE_IN = 0.25
      FADE_OUT = 0.3
      SILENT = 1.4 # long enough to read the name
      # The last click, then two beats: the block goes dark at once, and
      # holds dark for most of the second before the fade out.
      SOUNDING = JINGLE.last.at + (2 * BEAT)
      SKIPPED_BY = %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_SPLASH].freeze
      LIGHTS = 0.03 # seconds the block takes to light
      FADES = 0.1 # and to go dark

      def self.start(sounding: false, calm: false) = new(at: 0.0, sounding:, calm:)

      # Whether the environment (+env+) asks for no splash: the bot, the GUI
      # director, and a plain request leave it out.
      def self.skipped?(env) = SKIPPED_BY.any? { !env.fetch(it, "").empty? }

      def advance(seconds) = with(at: at + seconds)

      # The jingle's notes that start from now until +seconds+ later.
      def notes(seconds) = !sounding || over? ? [] : JINGLE.select { it.at >= at && it.at < at + seconds }
      def total = sounding ? SOUNDING : SILENT
      def skip = with(at: total)
      def over? = at >= total

      # How much of the mark shows, 0 to 1.
      def mark = at < FADE_IN ? at / FADE_IN : fade_out

      # How much of the black ground shows: all of it until the fade out,
      # which shows the title under it.
      def ground = fade_out

      # How lit the block is, 0 to 1, before the mark's fade; always 1 when
      # muted or calm. Sounding, rising over LIGHTS from the start of a
      # lit span, and falling over FADES from its end.
      def block
        return 1.0 if calm || !sounding

        span = lit.reverse_each.find { |from, _| from <= at } or return 0.0
        from, to = span
        at < to ? ((at - from) / LIGHTS).clamp(0.0, 1.0) : (1 - ((at - to) / FADES)).clamp(0.0, 1.0)
      end

      private

      # When the block is lit, as [from, to] seconds.
      def lit
        JINGLE.each_slice(2).map { |on, off| [on.at, off.at] }
      end

      def fade_out = ((total - at) / FADE_OUT).clamp(0.0, 1.0)
    end
  end
end
