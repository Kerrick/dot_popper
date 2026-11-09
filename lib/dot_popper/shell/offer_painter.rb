# frozen_string_literal: true

module DotPopper
  module Shell
    # The offer of Pro, over the Stats screen: what it
    # includes, a dot before each, the price from the store on its button,
    # and Restore Purchases; or, once it is the player's, thanks. Calm: no
    # motion, no countdown, and Back always there. Presentation::OfferScreen
    # decides where each goes; this only draws, on whole device pixels.
    class OfferPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        plan = show.offer_plan
        words = show.words.offer
        palette = pen.palette
        centered(plan, :heading, :bold, :heading, words[:heading], palette.cream)
        items(plan, words)
        note(plan) if plan.key?(:note)
        centered(plan, :status, :semibold, :note, show.offer_status, palette.cream)
        buttons(show, plan, words) if plan.key?(:buy)
        PillButton.new(pen:).draw(layout.back_button, show.words.go_back, hover: show.hover.level(:back))
      end

      private

      def centered(plan, name, face, size, text, color)
        font = pen.fonts.public_send(face, plan.size(size))
        pen.text(text, font, plan[name].center_x, plan[name].center_y, color)
      end

      def note(plan)
        font = pen.fonts.semibold(plan.size(:note))
        plan.note_lines.each_with_index do |line, i|
          pen.text(line, font, plan[:note].center_x, plan[:note].y + (font.height * (i + 0.5)), pen.palette.soft)
        end
      end

      def items(plan, words)
        font = pen.fonts.semibold(plan.size(:item))
        rect = plan[:items]
        line = font.height * Presentation::OfferScreen::LINE
        words[:includes].each_with_index do |item, i|
          y = pen.pixels.snap(rect.y + (font.height / 2.0) + (i * line))
          pen.color(pen.palette.fresh_body)
          G.circle(:fill, pen.pixels.snap(rect.x + (font.height * 0.3)), y, font.height * 0.22, 32)
          pen.text(item, font, rect.x + (font.height * 1.2) + (font.width(item) / 2.0), y, pen.palette.cream)
        end
      end

      def buttons(show, plan, words)
        label = show.offer_price ? format(words[:buy], show.offer_price) : words[:retry]
        PrimaryButton.new(pen:).draw(plan[:buy], label, hover: show.hover.level(:buy), ratio: PillButton::LABEL)
        PillButton.new(pen:).draw(plan[:restore], words[:restore], hover: show.hover.level(:restore))
      end
    end
  end
end
