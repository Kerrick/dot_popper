# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the offer of the paid version puts its parts, worked out by
    # OfferScreen#plan: each block's Rect by name (Stacked) and the font
    # size each is set in, and the note broken into lines.
    class OfferPlan < Data.define(:placed, :sizes, :note_lines)
      def [](name) = placed[name]
      def key?(name) = placed.key?(name)
      def size(name) = sizes.fetch(name)
    end

    # The offer, over the Stats screen: the heading, what is included, a
    # note of the games left and when more come (+note+), a line for how
    # the store is getting on (kept even while empty, so nothing moves when
    # it speaks), and the two buttons. Short of room the type shrinks;
    # what is sold, when free games come, its price and Restore Purchases
    # always stay. The buttons are the plan's only while +offering+: a player who owns it
    # has nothing left to press here but Back.
    class OfferScreen < Data.define(:layout, :type, :words, :measure, :offering, :note)
      GAPS = { items: 16, note: 14, status: 8, buy: 10, restore: 12 }.freeze
      LINE = 1.3 # the items apart, in a line's height
      WIDE = 7.0 # the widest the buttons are, in their height

      def initialize(layout:, type:, words:, measure:, offering:, note: nil)
        super(layout:, type:, words:, measure:, offering:, note: note || words.offer_note(0, FreeGames::DAILY))
      end

      def plan
        placed = Column.new(room:).fit(layout.type_scales) { blocks(sizes(it), it) }
        sizes = sizes(placed.scale)
        OfferPlan.new(placed:, sizes:, note_lines: note_lines(sizes[:note]))
      end

      # The safe area above the Back button.
      def room
        safe = layout.safe
        inside = safe.width - (2 * layout.margin)
        Rect.new(x: safe.x + layout.margin, y: safe.y + layout.margin, width: inside,
                 height: layout.back_button.y - layout.margin - safe.y - layout.margin)
      end

      private

      def blocks(sizes, scale)
        [text(:heading, :bold, sizes[:heading], words.offer[:heading], 0.0),
         items(sizes[:item], scale),
         note_block(sizes[:note], scale),
         status(sizes[:note], scale),
         *buttons(scale)]
      end

      def text(name, face, size, words, gap, drop: nil)
        Block.new(name:, height: measure.height(face, size), gap:, width: measure.width(face, size, words), drop:)
      end

      def items(size, scale)
        list = words.offer[:includes]
        line = measure.height(:semibold, size)
        widest = list.map { measure.width(:semibold, size, it) }.max
        Block.new(name: :items, height: (line * LINE * (list.size - 1)) + line, width: widest + (line * 1.2),
                  gap: gap(:items, scale))
      end

      def note_block(size, scale)
        lines = note_lines(size)
        line = measure.height(:semibold, size)
        Block.new(name: :note, height: line * lines.size, gap: gap(:note, scale),
                  width: lines.map { measure.width(:semibold, size, it) }.max)
      end

      # The note, broken evenly where it would not fit across.
      def note_lines(size) = Words.balance(note, room.width) { measure.width(:semibold, size, it) }

      def status(size, scale)
        Block.new(name: :status, height: measure.height(:semibold, size), width: room.width, gap: gap(:status, scale))
      end

      def buttons(scale)
        return [] unless offering

        height = layout.button_size
        width = [height * WIDE, room.width].min
        [Block.new(name: :buy, height:, width:, gap: gap(:buy, scale)),
         Block.new(name: :restore, height:, width:, gap: gap(:restore, scale))]
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { heading: size[type.new_best], item: size[type.hint], note: size[type.summary] }
      end
    end
  end
end
