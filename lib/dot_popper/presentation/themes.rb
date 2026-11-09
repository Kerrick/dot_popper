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
    # Back: one card for each theme, all in one row where each still has
    # room for its name, and otherwise two to a row, the first across the
    # whole width when the count is odd. The cards sit a little above the
    # middle of their room. On a controller, LB and RB stand at the top
    # right, where Back's row is on a short window.
    class ThemesLayout < Data.define(:layout, :themes, :style)
      NARROWEST = 150.0 # a card's least width in a single row

      def heading_size = layout.heading_size
      def heading_y = layout.heading_y

      def cards
        gap = layout.page_margin * 0.6
        across = (room.width - ((themes.size - 1) * gap)) / themes.size
        width = [across, layout.scaled(style.widest)].min
        return row(width, gap) if width >= NARROWEST && width * style.ratio <= room.height

        grid(gap)
      end

      # LB and RB, the previous and the next theme, at the top right.
      def steps
        size = layout.control_height
        width = size * 1.3
        right = layout.safe.right - layout.page_margin
        y = layout.short? ? layout.back_button.y : layout.safe.y + layout.page_margin
        [[:theme_prev, Rect.new(x: right - (2 * width) - 8, y:, width:, height: size)], [:theme_next, Rect.new(x: right - width, y:, width:, height: size)]]
      end

      private

      def room = layout.page

      def row(width, gap)
        height = width * style.ratio
        left = layout.center_x - (((themes.size * width) + ((themes.size - 1) * gap)) / 2.0)
        top = room.y + [(room.height - height) / 3.0, 0.0].max
        themes.each_with_index.map { |theme, i| ThemeCard.new(theme:, rect: Rect.new(x: left + (i * (width + gap)), y: top, width:, height:)) }
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
