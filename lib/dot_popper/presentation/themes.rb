# frozen_string_literal: true

module DotPopper
  module Presentation
    # Sizes for the Themes screen, in graphics units at a scale of 1: the
    # heading's type, the gap between cards in margins, a card's height as
    # a share of its width, the widest a card grows, and the type of the
    # note a free player is given.
    class ThemesStyle < Data.define(:heading, :gap, :ratio, :widest); end

    # One theme on the Themes screen, where it is drawn.
    class ThemeCard < Data.define(:theme, :rect); end

    # The Themes screen laid out under its heading (Layout#heading_y), over
    # Back: one card for each theme, in as few rows of equal count as
    # give each card room for its name (one row while they fit), and
    # otherwise two to a row, the first across the whole width when the
    # count is odd. The cards sit a little above the
    # middle of their room. On a controller, LB and RB stand at the top
    # right, where Back's row is on a short window.
    class ThemesLayout < Data.define(:layout, :themes, :style)
      NARROWEST = 150.0 # a card's least width in a row of them
      ROWS = 3 # the most rows of them before two to a row

      def heading_size = layout.heading_size
      def heading_y = layout.heading_y

      def cards
        gap = layout.page_margin * 0.6
        (1..ROWS).each do |rows|
          per = (themes.size / rows.to_f).ceil
          across = (room.width - ((per - 1) * gap)) / per
          width = [across, layout.scaled(style.widest)].min
          return rows_of(per, width, gap) if width >= NARROWEST && (rows * width * style.ratio) + ((rows - 1) * gap) <= room.height
        end
        grid(gap)
      end

      # LB and RB, the previous and the next theme, at the top right.
      def steps
        size = layout.control_height
        width = size * 1.6
        right = layout.safe.right - layout.page_margin
        y = layout.short? ? layout.back_button.y : layout.safe.y + layout.page_margin
        [[:theme_prev, Rect.new(x: right - (2 * width) - 8, y:, width:, height: size)], [:theme_next, Rect.new(x: right - width, y:, width:, height: size)]]
      end

      private

      def room = layout.page

      # Rows of +per+ cards, each row centered, the block a little above
      # the middle of the room.
      def rows_of(per, width, gap)
        height = width * style.ratio
        slices = themes.each_slice(per).to_a
        block = (slices.size * height) + ((slices.size - 1) * gap)
        top = room.y + [(room.height - block) / 3.0, 0.0].max
        slices.each_with_index.flat_map do |slice, r|
          left = layout.center_x - (((slice.size * width) + ((slice.size - 1) * gap)) / 2.0)
          y = top + (r * (height + gap))
          slice.each_with_index.map { |theme, i| ThemeCard.new(theme:, rect: Rect.new(x: left + (i * (width + gap)), y:, width:, height:)) }
        end
      end

      def grid(gap)
        width = (room.width - gap) / 2.0
        rows = (themes.size / 2.0).ceil
        height = [width * style.ratio * 0.9, (room.height - ((rows - 1) * gap)) / rows].min
        first, *rest = themes.size.odd? ? [themes.first(1), *themes.drop(1).each_slice(2)] : themes.each_slice(2).to_a
        top = room.y
        [first, *rest].each_with_index.flat_map do |slice, r|
          y = top + (r * (height + gap))
          if slice.size == 1
            [ThemeCard.new(theme: slice.first, rect: Rect.new(x: room.x, y:, width: room.width, height:))]
          else
            slice.each_with_index.map { |theme, i| ThemeCard.new(theme:, rect: Rect.new(x: room.x + (i * (width + gap)), y:, width:, height:)) }
          end
        end
      end
    end
  end
end
