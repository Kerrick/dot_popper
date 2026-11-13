# frozen_string_literal: true

module DotPopper
  module Shell
    # The card that tells of a new theme, once, at a calm moment on
    # Home: the theme's own two dots for a preview, its name, and an
    # immediate switch beside "Not now". Calm, and always answerable.
    # Presentation::ArrivalPlan decides where each part goes.
    class ArrivalPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        theme = show.arrival
        plan = show.arrival_plan
        words = show.words.themes
        veil(layout)
        card(plan)
        preview(plan, theme)
        cream = pen.palette.cream
        pen.text(words.fetch(:new), pen.fonts.semibold(plan.heading_size), plan.card.center_x, plan.heading_y, pen.palette.soft)
        pen.text(words.fetch(theme.key), pen.fonts.bold(plan.name_size), plan.card.center_x, plan.name_y, cream)
        PrimaryButton.new(pen:).draw(plan.use_button, show.arrival_use_word, hover: show.hover.level(:arrival_use))
        PillButton.new(pen:).draw(plan.later_button, words.fetch(:later), hover: show.hover.level(:arrival_later))
      end

      private

      def veil(layout)
        pen.color(pen.palette.ink_edge, 0.72)
        G.rectangle(:fill, layout.safe.x - 400, layout.safe.y - 400, layout.safe.width + 800, layout.safe.height + 800)
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
