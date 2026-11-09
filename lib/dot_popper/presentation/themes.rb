# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the Looks screen, in graphics units at a scale of 1: the
    # heading's type, the gap between cards in margins, a card's height as
    # a share of its width, the widest a card grows, and the type of the
    # note a free player is given.
    class ThemesStyle < Data.define(:heading, :gap, :ratio, :widest, :note); end

    # One look on the Looks screen, where it is drawn.
    class ThemeCard < Data.define(:theme, :rect); end

    # The Looks screen laid out in the safe area: the heading at the top,
    # Back (Layout#back_button) at the bottom, and between them one card
    # for each look, in the most even grid the room allows, as large as it
    # can be and no larger than +look.widest+. The grid sits a little above
    # the middle of its room, and a short last row is centred.
    class ThemesLayout < Data.define(:layout, :themes, :style, :note)
      def heading_size = layout.scaled(style.heading)
      def heading_y = layout.top + (heading_size * 0.6)
      def note_size = layout.scaled(style.note)

      # The middle of the one line a free player is told, under the heading.
      def note_y = heading_y + (heading_size * 0.8) + (note_size * 0.6)

      def cards
        columns, width = best
        height = width * style.ratio
        gap = layout.margin * style.gap
        rows = themes.each_slice(columns).to_a
        block = (rows.size * height) + ((rows.size - 1) * gap)
        top = room.y + [(room.height - block) / 3.0, 0.0].max
        rows.each_with_index.flat_map do |row, r|
          left = layout.center_x - (((row.size * width) + ((row.size - 1) * gap)) / 2.0)
          row.each_with_index.map do |theme, i|
            ThemeCard.new(theme:, rect: Rect.new(x: left + (i * (width + gap)), y: top + (r * (height + gap)), width:, height:))
          end
        end
      end

      private

      # What the cards may fill: under the heading, over Back.
      def room
        top = note ? note_y + (note_size * 0.8) : heading_y + (heading_size * 0.8)
        bottom = layout.back_button.y - layout.margin
        Rect.new(x: layout.safe.x + layout.margin, y: top, width: layout.safe.width - (2 * layout.margin),
                 height: [bottom - top, 0.0].max)
      end

      # The number of columns and the card width that make the biggest
      # cards; among those within a sixth of the biggest, the grid
      # nearest square.
      def best
        gap = layout.margin * style.gap
        sizes = (1..themes.size).map do |columns|
          rows = (themes.size.to_f / columns).ceil
          across = (room.width - ((columns - 1) * gap)) / columns
          down = (room.height - ((rows - 1) * gap)) / rows / style.ratio
          [columns, [across, down, layout.scaled(style.widest)].min, rows]
        end
        biggest = sizes.map { it[1] }.max
        columns, width, = sizes.select { it[1] >= biggest * 5 / 6.0 }.min_by { (it[0] - it[2]).abs }
        [columns, width]
      end
    end
  end
end
