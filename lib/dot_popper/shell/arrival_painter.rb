# frozen_string_literal: true

module DotPopper
  module Shell
    # The card that tells of a new theme, once, at a calm moment on
    # Home: the theme's own two dots for a preview, its name, and an
    # immediate switch beside "Not now". Calm, and always answerable.
    # Presentation::ArrivalPlan decides where each part goes, and the
    # screen hands it all (Presentation::ArrivalDrawing).
    class ArrivalPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(drawing)
        plan = drawing.plan
        veil(drawing.veil)
        card(plan)
        preview(plan, drawing.theme)
        cream = pen.palette.cream
        pen.text(drawing.heading, pen.fonts.semibold(plan.heading_size), plan.card.center_x, plan.heading_y, pen.palette.soft)
        pen.text(drawing.name, pen.fonts.bold(plan.name_size), plan.card.center_x, plan.name_y, cream)
        PrimaryButton.new(pen:).draw(plan.use_button, drawing.use, hover: drawing.use_hover)
        PillButton.new(pen:).draw(plan.later_button, drawing.later, hover: drawing.later_hover)
      end

      private

      def veil(rect)
        pen.color(pen.palette.ink_edge, 0.72)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height)
      end

      def card(plan)
        rect = plan.card
        corner = pen.pixels.snap(rect.height * 0.06)
        pen.color(pen.palette.ink_top)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        pen.color(pen.palette.pill_edge)
        G.line_width = pen.pixels.line_width(1.5)
        G.rectangle(:line, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end

      def preview(plan, theme)
        r = plan.preview_radius
        x = plan.card.center_x
        y = plan.preview_y
        pen.using(theme) do
          dots.icon(x - (r * 1.15), y, r, bright: true)
          dots.icon(x + (r * 1.15), y, r, bright: false)
        end
      end
    end
  end
end
