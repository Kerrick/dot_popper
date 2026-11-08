# frozen_string_literal: true

module DotPopper
  module Shell
    # The Looks screen, over the title's dimmed dots, which already wear the
    # look the player last chose: the heading, one card for each look, and
    # Back in the bottom left corner. A card is its look in small: its own
    # night, with a bright dot partly under a popped one, as in the game,
    # and its name beneath. The look being worn has a thick cream outline
    # and a check, so what is chosen shows without a word. Presentation::
    # LooksLayout decides where each card goes; this only draws, on whole
    # device pixels.
    class LooksPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        plan = show.looks_layout
        pen.text(show.words.looks.fetch(:title), pen.fonts.bold(plan.heading_size), layout.center_x, plan.heading_y,
                 pen.palette.cream)
        note(show, plan, layout) if plan.note
        plan.cards.each { card(it, show) }
        PillButton.new(pen:).draw(layout.clear_records_button, show.words.offer[:entry], alpha: 0.8 + (0.2 * show.hover.level(:offer)),
                                  hover: show.hover.level(:offer), color: pen.palette.soft) if plan.note && show.offer_offered?
        PillButton.new(pen:).draw(layout.back_button, show.words.go_back, hover: show.hover.level(:back))
      end

      private

      # For a free player, the one line that says where looks come from.
      def note(show, plan, layout)
        pen.text(show.words.looks.fetch(:locked), pen.fonts.semibold(plan.note_size), layout.center_x, plan.note_y, pen.palette.soft)
      end

      def card(card, show)
        theme = card.theme
        palette = theme.palette
        rect = snapped(card.rect)
        corner = [rect.height * 0.12, 6.0].max
        chosen = theme == show.worn
        hover = show.hover.level(theme)
        pen.color(palette.ink_top)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        pair(rect, palette)
        name(show.words.looks.fetch(theme.key), rect, palette)
        locked = show.looks_locked?
        earned = show.look_earned?(theme)
        shade(rect, corner, palette) if locked && !earned
        outline(rect, corner, chosen, hover)
        tick(rect, palette) if chosen
        badge(rect, palette, earned) if locked && !chosen
      end

      # A look not earned yet is dimmed, so what is earned is plain.
      def shade(rect, corner, palette)
        pen.color(palette.ink_bottom, 0.6)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end

      # A free player's mark in a card's top right corner, as the Records
      # screen's achievements wear theirs: a filled dot if earned, a ring if
      # not.
      def badge(rect, palette, earned)
        size = pen.pixels.whole([rect.height * 0.2, 22.0].max)
        x = pen.pixels.snap(rect.right - (size * 0.9))
        y = pen.pixels.snap(rect.y + (size * 0.9))
        pen.color(palette.fresh_light)
        if earned
          G.circle(:fill, x, y, size * 0.3, 24)
        else
          G.line_width = pen.pixels.line_width(2)
          G.circle(:line, x, y, size * 0.3, 24)
        end
      end

      # A bright dot, and over its right side a popped one, in the upper
      # part of the card.
      def pair(rect, palette)
        radius = pen.pixels.whole([rect.height * 0.25, rect.width * 0.19].min)
        y = pen.pixels.snap(rect.y + (rect.height * 0.42))
        left = rect.center_x - (radius * 0.55)
        dots.swatch(pen.pixels.snap(left - radius * 0.55), y, radius, palette, fresh: true)
        dots.swatch(pen.pixels.snap(left + radius * 1.1), y, radius, palette, fresh: false)
      end

      def name(text, rect, palette)
        size = (rect.height * 0.15).round
        size -= 1 while size > 10 && pen.fonts.semibold(size).width(text) > rect.width * 0.9
        pen.text(text, pen.fonts.semibold(size), rect.center_x, rect.bottom - (rect.height * 0.14), palette.cream)
      end

      def outline(rect, corner, chosen, hover)
        pixels = pen.pixels
        count = chosen ? 3 : 1
        width = pixels.line_width(count)
        pen.color(chosen ? pen.palette.cream : pen.palette.soft.mix(pen.lit.edge, hover), chosen ? 1.0 : 0.55 + (0.45 * hover))
        G.line_width = width
        inset = pixels.line_at(rect.x, count) - rect.x
        G.rectangle(:line, rect.x + inset, rect.y + inset, rect.width - (2 * inset), rect.height - (2 * inset), corner,
                    corner, 32)
      end

      # A cream disc in the card's top right corner with a check in ink.
      def tick(rect, palette)
        size = pen.pixels.whole([rect.height * 0.2, 22.0].max)
        x = pen.pixels.snap(rect.right - (size * 0.9))
        y = pen.pixels.snap(rect.y + (size * 0.9))
        pen.color(pen.palette.cream)
        G.circle(:fill, x, y, size / 2.0, 32)
        pen.color(palette.ink_bottom)
        G.line_width = pen.pixels.whole(size * 0.12)
        G.line(x - (size * 0.2), y, x - (size * 0.05), y + (size * 0.16), x + (size * 0.22), y - (size * 0.16))
      end

      def snapped(rect)
        pixels = pen.pixels
        Presentation::Rect.new(x: pixels.snap(rect.x), y: pixels.snap(rect.y), width: pixels.snap(rect.width),
                               height: pixels.snap(rect.height))
      end
    end
  end
end
