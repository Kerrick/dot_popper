# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the card that tells of a new theme puts its parts, on the
    # title, in the safe area: a preview of the theme's two dots, its name,
    # and two buttons, the switch as prominent as Play and "Not now"
    # beside it. A phone held upright stacks the buttons.
    class ArrivalPlan < Data.define(:layout)
      def card
        safe = layout.safe
        width = [safe.width * 0.88, layout.scaled(520)].min
        height = [safe.height * 0.86, layout.scaled(440), width * 0.82].min
        Rect.new(x: safe.x + ((safe.width - width) / 2.0), y: safe.y + ((safe.height - height) / 2.0), width:, height:)
      end

      def stacked? = card.width < layout.scaled(380)
      def button_height = [card.height * (stacked? ? 0.13 : 0.17), layout.scaled(44)].max
      def heading_y = card.y + (card.height * (stacked? ? 0.11 : 0.15))
      def heading_size = button_height * 0.42
      def name_size = button_height * 0.62
      def preview_y = card.y + (card.height * (stacked? ? 0.33 : 0.36))
      def preview_radius = card.height * 0.13
      def name_y = card.y + (card.height * (stacked? ? 0.54 : 0.6))

      def wear_button
        y = stacked? ? later_button.y - button_height - (card.height * 0.03) : row_y
        Rect.new(x: stacked? ? inset : inset + later_width + gap, y:, width: stacked? ? full : full - later_width - gap, height: button_height)
      end

      def later_button
        return Rect.new(x: inset, y: card.bottom - button_height - (card.height * 0.05), width: full, height: button_height) if stacked?

        Rect.new(x: inset, y: row_y, width: later_width, height: button_height)
      end

      private

      def row_y = card.bottom - button_height - (card.height * 0.06)
      def inset = card.x + (card.width * 0.06)
      def full = card.width * 0.88
      def gap = card.width * 0.04
      def later_width = card.width * 0.32
    end
  end
end
