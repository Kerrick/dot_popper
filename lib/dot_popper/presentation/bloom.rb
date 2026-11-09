# frozen_string_literal: true

module DotPopper
  module Presentation
    # The glow that fresh dots and droplets cast (Shell::Bloom): what
    # glows is drawn at the screen's full resolution, blurred at
    # +resolution+ of it (only the blur, which is soft anyway), and added
    # over the scene at +strength+. +sigma+ is the blur's spread in the
    # blurred layer's pixels, and +passes+ how many times it is blurred
    # each way, which widens it smoothly.
    class BloomStyle < Data.define(:strength, :sigma, :passes, :resolution)
      # The blurred layer's size in pixels, for a screen of +width+ by
      # +height+ pixels: never empty.
      def blurred_size(width, height) = [width, height].map { [(it * resolution).round, 1].max }

      def kernel = BlurKernel.gaussian(sigma)
    end

    # A Gaussian blur's nine taps folded into five texture reads: the
    # centre, and on each side two reads that fall between a pair of
    # pixels, where the GPU's linear filter blends the pair in the right
    # proportion. +offsets+ are in pixels from the centre and +weights+
    # what each read counts, the centre first.
    class BlurKernel < Data.define(:offsets, :weights)
      def self.gaussian(sigma)
        taps = (0..4).map { Math.exp(-(it**2) / (2.0 * (sigma**2))) }
        total = taps.first + (2 * taps.drop(1).sum)
        taps = taps.map { it / total }
        pairs = [[1, 2], [3, 4]].map do |near, far|
          weight = taps[near] + taps[far]
          [((near * taps[near]) + (far * taps[far])) / weight, weight]
        end
        new(offsets: [0.0] + pairs.map(&:first), weights: [taps.first] + pairs.map(&:last))
      end

      # The standard deviation, in pixels, of the blur the nine taps make:
      # less than +sigma+, since the taps stop at four pixels.
      def self.spread(sigma)
        taps = (-4..4).map { [it, Math.exp(-(it**2) / (2.0 * (sigma**2)))] }
        total = taps.sum(&:last)
        Math.sqrt(taps.sum { |at, weight| at * at * weight } / total)
      end

      # The sigma whose taps spread +wanted+ pixels (at most about 2.5).
      def self.sigma_for(wanted)
        low, high = 0.01, 1000.0
        60.times do
          middle = (low + high) / 2
          spread(middle) < wanted ? low = middle : high = middle
        end
        high
      end

      # What every read counts together, both sides: 1 for a blur that
      # neither brightens nor darkens.
      def total = weights.first + (2 * weights.drop(1).sum)
    end
  end
end
