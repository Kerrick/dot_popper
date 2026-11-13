# frozen_string_literal: true

module DotPopper
  module Shell
    # Settings, as Presentation::SettingsScreen lays it out: each row's
    # name and its choices, then Credits and licenses and Privacy, and Back.
    class SettingsPainter < Data.define(:pen, :dots)
      def draw(show, layout)
        plan = show.settings_plan
        Header.new(pen:).draw(show, layout, show.words.button(:settings_heading))
        page = layout.page
        pixels = pen.pixels
        ::Lota::Graphics.scissor = pixels.snap(layout.safe.x), pixels.snap(page.y), pixels.snap(layout.safe.width), pixels.snap(page.height)
        plan.rows.each { row(show, it) }
        pill(show, :credits, plan.credits, :document, show.words.button(:credits_licenses))
        pill(show, :privacy, plan.privacy, :shield, show.words.button(:privacy))
        pill(show, :server, plan.server, :crown, show.words.button(:server)) if plan.server
        ::Lota::Graphics.scissor = nil
      end

      private

      def row(show, row)
        label(row)
        choices = row.choices.zip(row.rects).map do |(text, chosen, name), _rect|
          [text, chosen, show.hover.level(name), icon(show, row, name)]
        end
        ChoiceRow.new(pen:).draw(row.frame, row.rects, choices)
      end

      # The name and its small mark, on one line.
      def label(row)
        x, y = row.label_at
        font = pen.fonts.semibold(18)
        if row.glyph == :dot
          dots.icon(x + 11, y, 11, bright: true)
        else
          Glyphs.new(pen:).draw(row.glyph, x + 11, y, 22, color: pen.palette.cream, weight: 1.6)
        end
        pen.text(row.label, font, x + 32 + (font.width(row.label) / 2.0), y, pen.palette.cream)
      end

      # A bright dot at the size a Dot size choice gives.
      def icon(show, row, name)
        return unless row.key == :dot_size

        ->(x, y, height, _chosen) { dots.icon(x, y, show.sizing_preview.icon(name, height), bright: true) }
      end

      def pill(show, name, rect, glyph, text)
        PillButton.new(pen:).draw(rect, text, hover: show.hover.level(name),
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(glyph, x, y, size * 0.42) })
      end
    end

    # A screen's heading and Back (Presentation::HeaderDrawing): top left
    # beside the heading on a short window. Until every screen hands it a
    # HeaderDrawing, it makes one from the Show, its +layout+ and +heading+.
    class Header < Data.define(:pen)
      def draw(header, layout = nil, heading = nil)
        if layout
          show = header
          header = Presentation::HeaderDrawing.for(heading, layout:, measure: show.measure, words: show.words, hover: show.hover)
        end
        pen.text(header.text, pen.fonts.bold(header.size), header.x, header.y, pen.palette.cream)
        PillButton.new(pen:).draw(header.back, header.back_word, hover: header.back_hover,
                                  icon: ->(x, y, size) { Glyphs.new(pen:).draw(:chevron_left, x, y, size * 0.38) })
      end
    end
  end
end
