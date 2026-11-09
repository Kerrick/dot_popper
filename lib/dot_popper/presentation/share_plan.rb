# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the share preview's parts go, worked out by ShareScreen#plan:
    # each block's Rect by name (Stacked), the :heading, the :message
    # holding the result's lines, the :note under it, where "Copied! Paste
    # it anywhere." shows once copied, and the :buttons row; the font size each
    # is set in; the message broken into +lines+ that fit across it; the
    # +card+ behind them all; the +close+ and +copy+ buttons, side by side
    # in the buttons row, Copy on the right; and the +bubble+'s padding
    # around the message's lines (and +side+ at its sides).
    class SharePlan < Data.define(:placed, :sizes, :lines, :card, :close, :copy, :bubble, :side)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
    end

    # The share preview over Game Over: a card, as wide as its message
    # needs, up to what +look+ (SharePreviewLook) or the safe area
    # allows, in the middle of the screen, holding "Share your score", the result's +lines+ in a
    # message bubble, room for "Copied!" once Copy has copied, and Close
    # and Copy. Short
    # of room the type shrinks first, then the heading goes. The message,
    # the note's room and the buttons always stay, since they are what the
    # preview is for. Sizes are measured with +measure+ (RoughMeasure's
    # methods).
    class ShareScreen < Data.define(:layout, :type, :words, :measure, :look, :lines)
      # The gaps above each block, in graphics units at full size.
      GAPS = { heading: 0, message: 14, note: 12, buttons: 18 }.freeze
      LINE = 1.2 # the message's lines apart, in a line's height
      BUTTON = 3.4 # Close's and Copy's widest, in their height
      FACTS = " · " # what sets the game's facts apart in their line
      SIDE = 1.5 # the bubble's side padding, in its padding above
      KEEP = " " # a space no line breaks at

      def plan
        placed = Column.new(room:).fit(layout.type_scales) { blocks(sizes(it), it) }
        sizes = sizes(placed.scale)
        close, copy = buttons(placed[:buttons])
        SharePlan.new(placed:, sizes:, lines: wrapped(sizes[:message]), card: card(placed), close:, copy:, bubble:, side:)
      end

      # The card's inside, from a margin and its padding inside the safe
      # area, at most as wide as the look asks.
      def room
        inside = layout.margin + pad
        safe = layout.safe
        width = [safe.width - (2 * inside), look.width * layout.ui].min
        Rect.new(x: layout.center_x - (width / 2.0), y: safe.y + inside, width:, height: safe.height - (2 * inside))
      end

      # The message bubble's padding around its lines.
      def bubble = look.bubble * layout.ui

      # The message bubble's padding at its left and right: roomier than
      # above and below, since a line's last letter has no more to its
      # right than the line above has.
      def side = bubble * SIDE

      private

      def pad = look.pad * layout.ui

      def blocks(sizes, scale)
        heading = sizes[:heading]
        note = sizes[:note]
        [Block.new(name: :heading, height: measure.height(:bold, heading), gap: 0.0, drop: 1,
                   width: measure.width(:bold, heading, words.share_heading)),
         message(sizes[:message], scale),
         note_line(note, scale),
         Block.new(name: :buttons, height: layout.button_size, width: across(sizes[:message]),
                   gap: gap(:buttons, scale))]
      end

      # How wide the bubble and the buttons row are: as the result's
      # widest line needs, never narrower than Close and Copy at their
      # widest, nor wider than the card's room.
      def across(size)
        height = measure.height(:semibold, size)
        widest = wrapped(size).map { |line| ShareGlyphs.width(line, height) { measure.width(:semibold, size, it) } }.max
        buttons = (layout.button_size * BUTTON * 2) + layout.margin
        [[widest + (2 * side), buttons].max, room.width].min
      end

      # Room for "Copied! Paste it anywhere." with a check before it, kept
      # before Copy is pressed, so nothing moves when it shows.
      def note_line(size, scale)
        height = measure.height(:semibold, size)
        width = measure.width(:semibold, size, words.copied) + (height * 0.75)
        Block.new(name: :note, height:, width:, gap: gap(:note, scale))
      end

      # The result's lines in a bubble.
      def message(size, scale)
        line = measure.height(:semibold, size)
        count = wrapped(size).size
        Block.new(name: :message, height: (line * LINE * (count - 1)) + line + (2 * bubble), width: across(size),
                  gap: gap(:message, scale))
      end

      # Each of the result's lines, broken evenly where it would not fit
      # in the bubble, with its emoji drawn as shapes (ShareGlyphs). A
      # line of facts set apart by " · " breaks only after a "·", so "1
      # mistake" stays whole.
      def wrapped(size)
        across = room.width - (2 * side)
        height = measure.height(:semibold, size)
        lines.flat_map do |line|
          kept = line.include?(FACTS) ? line.split(FACTS).map { it.tr(" ", KEEP) }.join("#{KEEP}· ") : line
          Words.balance(kept, across) do |text|
            ShareGlyphs.width(text.tr(KEEP, " "), height) { measure.width(:semibold, size, it) }
          end.map { it.tr(KEEP, " ") }
        end
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { heading: size[type.score_record], message: size[type.hint], note: size[type.summary] }
      end

      # Close and Copy, each as tall as a button and half the row at
      # most, a margin apart and centred in it.
      def buttons(row)
        apart = layout.margin
        width = [(row.width - apart) / 2.0, row.height * BUTTON].min
        left = row.center_x - width - (apart / 2.0)
        [row.with(x: left, width:), row.with(x: left + width + apart, width:)]
      end

      # Around every block, padded.
      def card(placed) = placed.bounds.inset(-pad)
    end
  end
end
