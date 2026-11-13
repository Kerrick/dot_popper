# frozen_string_literal: true

module DotPopper
  module Shell
    # Settings, as Presentation::SettingsScreen lays it out: each row's
    # name and its choices, then Credits and licenses and Privacy, and Back,
    # as the screen hands it (Presentation::SettingsDrawing).
    class SettingsPainter < Data.define(:pen, :dots)
      def draw(drawing)
        plan = drawing.plan
        Header.new(pen:).draw(drawing.header)
        clip = drawing.clip
        pixels = pen.pixels
        ::Lota::Graphics.scissor = pixels.snap(clip.x), pixels.snap(clip.y), pixels.snap(clip.width), pixels.snap(clip.height)
        plan.rows.zip(drawing.choices).each { |row, choices| row(drawing, row, choices) }
        pill(drawing, :credits, plan.credits, :document, drawing.credits)
        pill(drawing, :privacy, plan.privacy, :shield, drawing.privacy)
        pill(drawing, :server, plan.server, :crown, drawing.server) if plan.server
        ::Lota::Graphics.scissor = nil
      end

      private

      def row(drawing, row, choices)
        label(row)
        drawn = choices.map { |text, chosen, hover, name| [text, chosen, hover, icon(drawing, row, name)] }
        ChoiceRow.new(pen:).draw(row.frame, row.rects, drawn)
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

      # A bright dot at the size a Dot size choice gives, its right edge a
      # set gap before the choice's name (ChoiceRow keeps 0.3 of the row's
      # height from the icon's middle to the name), so a dot drawn bigger
      # than the usual 0.16 grows away from the name, never over it.
      def icon(drawing, row, name)
        return unless row.key == :dot_size

        lambda do |x, y, height, _chosen|
          radius = drawing.sizing_preview.icon(name, height)
          dots.icon(x + (height * 0.16) - radius, y, radius, bright: true)
        end
      end

      def pill(drawing, name, rect, glyph, text)
        PillButton.new(pen:).draw(rect, text, hover: drawing.lit.fetch(name),
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
