# frozen_string_literal: true

module DotPopper
  module Shell
    # The Themes screen, over Home's dimmed dots, which already use the
    # theme the player last chose: the heading, one card for each theme, and
    # Back in the bottom left corner. A card is its theme in small: its own
    # night, with a bright dot partly under a popped one, as in the game,
    # and its name beneath. The theme in use has a thick cream outline
    # and a check, so what is chosen shows without a word. Presentation::
    # LooksLayout decides where each card goes; this only draws, on whole
    # device pixels.
    class ThemesPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics

      def draw(show, layout)
        plan = show.themes_layout
        Header.new(pen:).draw(show, layout, show.words.themes.fetch(:heading))
        plan.cards.each { card(it, show) }
        steps(show, plan) if show.input == Presentation::InputKind::GAMEPAD
      end

      # LB and RB, labeled with their arrows, at the top right.
      def steps(show, plan)
        glyphs = Glyphs.new(pen:)
        plan.steps.each do |name, rect|
          back = name == :theme_prev
          PillButton.new(pen:).draw(rect, back ? "LB" : "RB", hover: show.hover.level(name),
                                    icon: ->(x, y, size) { glyphs.draw(back ? :chevron_left : :chevron_right, x, y, size * 0.36) })
        end
      end

      private

      def card(card, show)
        theme = card.theme
        palette = theme.palette
        rect = snapped(card.rect)
        corner = [rect.height * 0.12, 6.0].max
        chosen = theme == show.in_use
        hover = show.hover.level(theme)
        pen.color(palette.ink_top)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
        pair(rect, theme)
        name(show.words.themes.fetch(theme.key), rect, theme)
        shade(rect, corner, palette) unless show.theme_open?(theme)
        outline(rect, corner, chosen, hover)
        tick(rect, palette) if chosen
      end

      # A theme neither earned nor in season is dimmed, so what is open is plain.
      def shade(rect, corner, palette)
        pen.color(palette.ink_bottom, 0.6)
        G.rectangle(:fill, rect.x, rect.y, rect.width, rect.height, corner, corner, 32)
      end

      # A mark in a card's top right corner, as the Stats screen's
      # achievements have theirs: a filled dot if earned, a ring if not.
      # A bright dot, and over its right side a popped one, in the upper
      # part of the card, in the theme's own art.
      def pair(rect, theme)
        radius = pen.pixels.whole([rect.height * 0.25, rect.width * 0.19].min)
        y = pen.pixels.snap(rect.y + (rect.height * 0.42))
        left = rect.center_x - (radius * 0.55)
        pen.using(theme) do
          dots.icon(pen.pixels.snap(left - radius * 0.55), y, radius, bright: true)
          dots.icon(pen.pixels.snap(left + radius * 1.1), y, radius, bright: false)
        end
      end

      # The theme's name in its own lettering and its bright dot's color,
      # as the game's name on Home is set.
      def name(text, rect, theme)
        art = theme.art
        face = art&.wordmark || pen.style::TYPE.bold
        text = text.upcase if art&.wordmark && art.dotted_name
        size = [(rect.height * 0.13).round, 24].min
        size -= 1 while size > 10 && pen.fonts.face(face, size).width(text) > rect.width * 0.9
        pen.text(text, pen.fonts.face(face, size), rect.center_x, rect.bottom - (rect.height * 0.2), theme.palette.bright_body)
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
