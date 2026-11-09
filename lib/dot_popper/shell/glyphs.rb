# frozen_string_literal: true

module DotPopper
  module Shell
    # The game's icons, drawn as thin strokes on a 24-unit grid centred on
    # 12, 12, so they stay crisp at any size, and the same for a Free and
    # a Pro player. Each is a list of parts: [:line, x, y, x, y, ...] a
    # stroked path, [:circle, x, y, r] a ring, [:disc, x, y, r] a filled
    # circle, [:arc, x, y, r, from, to] an open arc in degrees, and
    # [:fill, x, y, ...] a filled polygon.
    class Glyphs < Data.define(:pen)
      G = ::Lota::Graphics
      TABLE = {
        bars: [[:line, 4, 21, 4, 11], [:line, 10, 21, 10, 5], [:line, 16, 21, 16, 9], [:line, 22, 21, 22, 13]],
        ribbon: [[:circle, 12, 8, 6], [:line, 8.5, 13, 7, 21, 12, 18.5, 17, 21, 15.5, 13]],
        crown: [[:line, 2.5, 8, 7, 13, 12, 5, 17, 13, 21.5, 8, 19.5, 19, 4.5, 19, 2.5, 8]],
        question: [[:circle, 12, 12, 9.5], [:arc, 12, 9.3, 3, 200, 400], [:line, 12, 13, 12, 14.2], [:disc, 12, 17, 0.7]],
        gear: [[:circle, 12, 12, 3], [:circle, 12, 12, 7],
               *Array.new(8) do |i|
                 a = i * Math::PI / 4
                 [:line, 12 + (7 * Math.cos(a)), 12 + (7 * Math.sin(a)), 12 + (10 * Math.cos(a)), 12 + (10 * Math.sin(a))]
               end],
        power: [[:arc, 12, 13, 8.5, -50, 230], [:line, 12, 2.5, 12, 11]],
        home: [[:line, 3, 11, 12, 3, 21, 11], [:line, 5, 9.5, 5, 21, 19, 21, 19, 9.5], [:line, 10, 21, 10, 14, 14, 14, 14, 21]],
        share: [[:disc, 18, 5, 3], [:disc, 6, 12, 3], [:disc, 18, 19, 3], [:line, 8.5, 10.5, 15.5, 6.5], [:line, 8.5, 13.5, 15.5, 17.5]],
        chevron_left: [[:line, 15, 5, 8, 12, 15, 19]],
        chevron_right: [[:line, 9, 5, 16, 12, 9, 19]],
        plus: [[:line, 12, 4, 12, 20], [:line, 4, 12, 20, 12]],
        keypad: Array.new(9) { |i| [:disc, 6 + (6 * (i % 3)), 6 + (6 * (i / 3)), 1.4] },
        backspace: [[:line, 8, 5, 21, 5, 21, 19, 8, 19, 2, 12, 8, 5], [:line, 11, 9, 17, 15], [:line, 17, 9, 11, 15]],
        trash: [[:line, 4, 6.5, 20, 6.5], [:line, 9, 6.5, 9, 3.5, 15, 3.5, 15, 6.5], [:line, 6, 6.5, 7, 21, 17, 21, 18, 6.5]],
        leave: [[:line, 10, 3.5, 4, 3.5, 4, 20.5, 10, 20.5], [:line, 9, 12, 21, 12], [:line, 16, 7, 21, 12, 16, 17]],
        history: [[:arc, 12, 12, 9, 200, 505], [:line, 2, 9, 3.6, 13.5, 8, 11], [:line, 12, 7, 12, 12, 16, 14]],
        document: [[:line, 6, 2.5, 15, 2.5, 19.5, 7, 19.5, 21.5, 6, 21.5, 6, 2.5], [:line, 9, 12, 16.5, 12], [:line, 9, 16, 16.5, 16]],
        shield: [[:line, 12, 2.5, 20, 5.5, 20, 12, 12, 21.5, 4, 12, 4, 5.5, 12, 2.5]],
        external: [[:line, 11, 4, 4, 4, 4, 20, 20, 20, 20, 13], [:line, 14, 3, 21, 3, 21, 10], [:line, 21, 3, 11, 13]],
        infinity: [[:arc, 7, 12, 5.5, 45, 315], [:arc, 17, 12, 5.5, -135, 135], [:line, 11, 16, 13, 16], [:line, 11, 8, 13, 8]],
        speaker: [[:fill, 2.5, 9, 8, 9, 13, 4, 13, 20, 8, 15, 2.5, 15], [:arc, 13, 12, 5, -50, 50], [:arc, 13, 12, 9, -45, 45]],
        check: [[:line, 3, 12.5, 9.5, 19, 21, 6.5]],
        skip: [[:fill, 4, 4, 15, 12, 4, 20], [:line, 19, 5, 19, 19]],
        copy: [[:line, 9, 3, 21, 3, 21, 15, 9, 15, 9, 3], [:line, 15, 21, 3, 21, 3, 9]],
        corners: [[:line, 3, 8, 3, 3, 8, 3], [:line, 16, 3, 21, 3, 21, 8], [:line, 21, 16, 21, 21, 16, 21], [:line, 8, 21, 3, 21, 3, 16]],
        hourglass: [[:line, 5, 3, 19, 3], [:line, 5, 21, 19, 21], [:line, 7, 3, 12, 11, 17, 3], [:line, 7, 21, 12, 13, 17, 21]],
        crosshair: [[:circle, 12, 12, 7], [:circle, 12, 12, 3], [:line, 12, 1.5, 12, 7], [:line, 12, 17, 12, 22.5], [:line, 1.5, 12, 7, 12], [:line, 17, 12, 22.5, 12]],
        trio: [[:circle, 7, 8, 5], [:circle, 7, 8, 2], [:circle, 17, 8, 5], [:circle, 17, 8, 2], [:circle, 12, 17, 5], [:circle, 12, 17, 2]],
        eye: [[:arc, 12, 13, 11, 202, 338], [:arc, 12, 11, 11, 22, 158], [:circle, 12, 12, 3.5]],
        hand: [[:line, 7, 12, 7, 6, 9, 5, 11, 6, 11, 11], [:line, 11, 5, 13, 4, 15, 5, 15, 11], [:line, 15, 6, 17, 5.5, 19, 7, 19, 15, 17, 21, 10, 21, 5, 16, 5, 13.5, 7, 12.5]],
        mountain: [[:line, 2, 20, 9, 7, 13, 13, 16, 9, 22, 20, 2, 20]],
        shake: [[:circle, 12, 12, 3.5], [:arc, 12, 12, 7.5, 140, 220], [:arc, 12, 12, 7.5, -40, 40], [:arc, 12, 12, 11, 140, 220], [:arc, 12, 12, 11, -40, 40]],
        stairs: [[:line, 2, 21, 8, 21, 8, 15, 14, 15, 14, 9], [:line, 11, 12, 16, 7, 21, 12], [:line, 16, 7, 16, 19]],
        bolt: [[:line, 13, 2, 5, 13.5, 12, 13.5, 11, 22, 19, 9.5, 12, 9.5, 13, 2]],
        star: [[:line, 12, 3, 14.7, 9, 21.5, 9.6, 16.3, 14, 18, 20.8, 12, 17.2, 6, 20.8, 7.7, 14, 2.5, 9.6, 9.3, 9, 12, 3]],
        road: [[:line, 6, 22, 9, 2], [:line, 18, 22, 15, 2], [:line, 12, 4, 12, 7], [:line, 12, 10, 12, 13], [:line, 12, 16, 12, 19]]
      }.freeze

      # The icon +name+, in a square +size+ across around +x+, +y+. Thin
      # strokes unless +weight+ (in grid units) says otherwise.
      def draw(name, x, y, size, color: pen.palette.cream, alpha: 1.0, weight: 1.6)
        unit = size / 24.0
        pen.color(color, alpha)
        G.line_width = pen.pixels.whole([weight * unit, 1.0].max)
        G.line_join = :bevel if G.respond_to?(:line_join=)
        place = ->(px, py) { [x + ((px - 12) * unit), y + ((py - 12) * unit)] }
        TABLE.fetch(name).each { |part| stroke(part, unit, place) }
      end

      private

      def stroke(part, unit, place)
        case part
        in [:line, *points] then G.line(*points.each_slice(2).flat_map { place.call(*it) })
        in [:circle, cx, cy, r] then G.circle(:line, *place.call(cx, cy), r * unit, 40)
        in [:disc, cx, cy, r] then G.circle(:fill, *place.call(cx, cy), r * unit, 20)
        in [:fill, *points] then G.polygon(:fill, *points.each_slice(2).flat_map { place.call(*it) })
        in [:arc, cx, cy, r, from, to] then G.arc(:line, :open, *place.call(cx, cy), r * unit, from * Math::PI / 180.0, to * Math::PI / 180.0, 32)
        end
      end
    end

    # The dark rounded card the screens set their parts on, and the tiles
    # and choices built from it, on whole device pixels.
    class Card < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(rect, corner: nil, alpha: 1.0, lit: 0.0, edge: nil)
        pixels = pen.pixels
        x, y, width, height = [rect.x, rect.y, rect.width, rect.height].map { pixels.snap(it) }
        corner ||= [height * 0.26, 18.0].min
        palette = pen.palette
        fill = palette.pill.mix(pen.lit.fill, lit)
        pen.color(fill, [fill.a, 0.7].max * alpha)
        G.rectangle(:fill, x, y, width, height, corner, corner, 16)
        pen.color(edge || palette.soft.mix(pen.lit.edge, lit), (edge ? 1.0 : 0.3 + (0.7 * lit)) * alpha)
        G.line_width = pixels.line_width(1)
        inset = pixels.line_at(x) - x
        G.rectangle(:line, x + inset, y + inset, width - (2 * inset), height - (2 * inset), corner, corner, 16)
      end
    end

    # A row of choices in one pill, the chosen one filled in cream.
    # +choices+ are [text, chosen?, hover, icon], where +icon+ draws at
    # x, y in a square of the given size, or is nil.
    class ChoiceRow < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(frame, rects, choices)
        pixels = pen.pixels
        palette = pen.palette
        Card.new(pen:).draw(frame, corner: frame.height / 2.0)
        rects.zip(choices).each do |rect, (text, chosen, hover, icon)|
          inner = rect.inset(pixels.snap(frame.height * 0.08))
          x, y, width, height = [inner.x, inner.y, inner.width, inner.height].map { pixels.snap(it) }
          if chosen
            pen.color(palette.cream, 0.92 + (0.08 * hover))
            G.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 32)
          elsif hover.positive?
            pen.color(pen.lit.fill, pen.lit.fill.a * hover)
            G.rectangle(:fill, x, y, width, height, height / 2.0, height / 2.0, 32)
          end
          label(text, x + (width / 2.0), y + (height / 2.0), height, chosen, icon, width)
        end
      end

      private

      def label(text, x, y, height, chosen, icon, room)
        size = (height * 0.34).round
        size -= 1 while size > 11 && pen.fonts.semibold(size).width(text) + (icon ? height : 0) > room - (height * 0.4)
        font = pen.fonts.semibold(size)
        return pen.text(text, font, x, y, chosen ? pen.palette.ink_bottom : pen.palette.cream) unless icon

        left = x - ((height * 0.5) + font.width(text)) / 2.0
        icon.call(left + (height * 0.2), y, height, chosen)
        pen.text(text, font, left + (height * 0.5) + (font.width(text) / 2.0), y, chosen ? pen.palette.ink_bottom : pen.palette.cream)
      end
    end
  end
end
