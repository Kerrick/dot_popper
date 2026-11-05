# frozen_string_literal: true

module DotPopper
  module Presentation
    # One block of a Column: a line of words, a few lines, or a button,
    # +height+ units tall, +gap+ units below the block before it, and
    # +width+ units across, centred. A block with a +drop+ rank may be
    # left out when the column has no room for it, the lowest rank first;
    # one without is always kept.
    class Block < Data.define(:name, :height, :gap, :width, :drop)
      def initialize(name:, height:, gap: 0.0, width: 0.0, drop: nil) = super

      def optional? = !drop.nil?
    end

    # Where a Column put its blocks: each block's Rect by its name, at
    # the type +scale+ they were measured at, and whether they all fit.
    class Stacked < Data.define(:scale, :rects, :fits)
      def [](name) = rects[name]
      def key?(name) = rects.key?(name)
      def fits? = fits

      # The smallest Rect around every block, or nil with none.
      def bounds
        return if rects.empty?

        boxes = rects.values
        left = boxes.map(&:x).min
        top = boxes.map(&:y).min
        Rect.new(x: left, y: top, width: boxes.map(&:right).max - left, height: boxes.map(&:bottom).max - top)
      end
    end

    # Blocks stacked one under the next inside +room+ (a Rect), the first
    # block's gap left out, as a group centred down the room or from its
    # top (+align+ :center or :top). A group too tall for the room starts
    # at its top and runs past its bottom.
    #
    # Its blocks are measured at a type scale, so #fit asks for them at
    # each scale it tries, from the largest down: type shrinks by whole
    # sizes to a floor before anything is left out, and only then are the
    # optional blocks dropped, the least needed first, and the type grows
    # back as far as what is left allows.
    class Column < Data.define(:room, :align)
      def initialize(room:, align: :center) = super

      def height(blocks) = blocks.sum(&:height) + blocks.drop(1).sum(&:gap)
      def fits?(blocks) = height(blocks) <= room.height + 1e-6

      def place(blocks, scale: 1.0)
        total = height(blocks)
        y = align == :center && total < room.height ? room.y + ((room.height - total) / 2.0) : room.y
        rects = blocks.each_with_index.to_h do |block, i|
          y += block.gap unless i.zero?
          rect = Rect.new(x: room.center_x - (block.width / 2.0), y:, width: block.width, height: block.height)
          y += block.height
          [block.name, rect]
        end
        Stacked.new(scale:, rects:, fits: fits?(blocks))
      end

      # The blocks the block gives for each of +scales+, largest first,
      # placed at the largest scale they fit at, with as few optional
      # blocks dropped as that takes.
      def fit(scales, &blocks)
        dropped = dropped(scales.last, &blocks)
        scales.each do |scale|
          kept = kept(blocks.call(scale), dropped)
          return place(kept, scale:) if fits?(kept)
        end
        place(kept(blocks.call(scales.last), dropped), scale: scales.last)
      end

      private

      # The names of the blocks to leave out for the rest to fit at
      # +scale+, the lowest drop rank first; every optional one if even
      # that is not enough.
      def dropped(scale)
        blocks = yield(scale)
        blocks.select(&:optional?).sort_by(&:drop).each_with_object([]) do |block, names|
          break names if fits?(kept(blocks, names))

          names << block.name
        end
      end

      def kept(blocks, dropped) = blocks.reject { dropped.include?(it.name) }
    end
  end
end
