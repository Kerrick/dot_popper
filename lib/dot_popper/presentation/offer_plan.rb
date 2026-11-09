# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the offer of Pro puts its parts, worked out by
    # OfferScreen#plan: each block's Rect by name (Stacked), the font size
    # each is set in, and the note broken into lines.
    class OfferPlan < Data.define(:placed, :sizes, :note_lines)
      def [](name) = placed[name]
      def key?(name) = placed.key?(name)
      def size(name) = sizes.fetch(name)
    end

    # The offer of Pro, under its heading (Layout#heading_y) and over Back,
    # leading with what the player tapped (+focus+: :games, :achievements,
    # :themes or :groups): a +note+ when it opened for want of a game, the
    # thing itself shown (+art+ units tall: every theme the player would
    # get, an achievement and how to earn it, or the feature's sign), its
    # name, then the rest of what Pro adds, a line for how the store is
    # getting on (kept even while empty, so nothing moves when it speaks),
    # Buy and Restore Purchases. Short of room the type shrinks, then the
    # art goes. A short window held sideways puts the buttons on the right.
    # The buttons are the plan's only while +offering+: a player who owns
    # it has nothing left to press here but Back.
    class OfferScreen < Data.define(:layout, :type, :words, :measure, :offering, :note, :focus, :art)
      GAPS = { note: 0, art: 14, focus: 10, items: 12, status: 10, buy: 12, restore: 10 }.freeze
      LINE = 1.45 # the items apart, in a line's height
      WIDE = 560.0 # the widest the buttons are

      def initialize(layout:, type:, words:, measure:, offering:, note: nil, focus: nil, art: 0.0)
        super(layout:, type:, words:, measure:, offering:, note:, focus: focus || :games, art:)
      end

      def plan
        return sideways if layout.short? && offering

        placed = Column.new(room:).fit(layout.type_scales) { top(it) + buttons(it, room.width) }
        finish(placed)
      end

      # Under the heading, over Back, or beside Back on a short window.
      def room = layout.page

      # What Pro adds besides the thing the offer leads with.
      def others = words.offer_items(focus).drop(1)

      # The name of the thing it leads with, or "Dot Popper Pro"'s first.
      def focus_word = words.offer_items(focus).first

      private

      def sideways
        whole = room
        gap = layout.page_margin
        left = whole.with(width: (whole.width - gap) / 2.0)
        right = whole.with(x: left.right + gap, width: left.width)
        scale = layout.type_scales.find { Column.new(room: left).fits?(top(it, left.width)) } || layout.type_scales.last
        one = Column.new(room: left).fit([scale]) { top(it, left.width) }
        two = Column.new(room: right).fit([scale]) { buttons(it, right.width) }
        finish(Stacked.new(scale:, rects: one.rects.merge(two.rects), fits: one.fits? && two.fits?))
      end

      def finish(placed)
        sizes = sizes(placed.scale)
        OfferPlan.new(placed:, sizes:, note_lines: note_lines(sizes[:note]))
      end

      def top(scale, across = room.width)
        sizes = sizes(scale)
        [(note_block(sizes[:note], scale) if note),
         (Block.new(name: :art, height: art * scale, width: across, gap: gap(:art, scale), drop: 1) if art.positive?),
         text(:focus, :bold, sizes[:focus], focus_word, gap(:focus, scale)),
         items(sizes[:item], scale),
         Block.new(name: :status, height: measure.height(:semibold, sizes[:note]), width: across, gap: gap(:status, scale))].compact
      end

      def text(name, face, size, words, gap, drop: nil)
        Block.new(name:, height: measure.height(face, size), gap:, width: measure.width(face, size, words), drop:)
      end

      def items(size, scale)
        line = measure.height(:semibold, size)
        widest = others.map { measure.width(:semibold, size, it) }.max.to_f
        Block.new(name: :items, height: (line * LINE * (others.size - 1)) + line, width: widest + (line * 1.6), gap: gap(:items, scale))
      end

      def note_block(size, scale)
        lines = note_lines(size)
        line = measure.height(:semibold, size)
        Block.new(name: :note, height: line * lines.size, gap: gap(:note, scale), width: lines.map { measure.width(:semibold, size, it) }.max)
      end

      # The note, broken evenly where it would not fit across.
      def note_lines(size) = note ? Words.balance(note, room.width) { measure.width(:semibold, size, it) } : []

      def buttons(scale, across)
        return [] unless offering

        width = [WIDE, across].min
        [Block.new(name: :buy, height: [80.0 * scale, layout.button_size].max, width:, gap: gap(:buy, scale)),
         Block.new(name: :restore, height: layout.control_height, width:, gap: gap(:restore, scale))]
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { focus: size[type.new_score_record], item: size[type.hint], note: size[type.summary] }
      end
    end
  end
end
