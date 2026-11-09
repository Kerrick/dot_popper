# frozen_string_literal: true

module DotPopper
  module Shell
    # The Credits screen, over the title's dimmed dots: the heading as
    # the Stats screen has it, Back in the bottom left corner, and between
    # them the license texts, scrolled, in the same type and palette, each
    # line on whole device pixels and clipped to its window. A faint bar
    # beside the window shows where in the page it is.
    # Presentation::CreditsLayout decides where each goes.
    class CreditsPainter < Data.define(:pen)
      G = ::Lota::Graphics

      def draw(show, layout)
        page = show.credits_layout
        Header.new(pen:).draw(show, layout, show.words.button(:credits_title))
        window = page.window
        text(show.credits_lines, show.credits.offset, window, page)
        bar(show.credits, window, layout)
      end

      private

      def text(lines, offset, window, page)
        pixels = pen.pixels
        G.scissor = pixels.snap(window.x), pixels.snap(window.y), pixels.snap(window.width), pixels.snap(window.height)
        fonts = { heading: pen.fonts.bold(Presentation::CreditsLines.heading_size(lines.size)),
                  subheading: pen.fonts.bold(lines.size),
                  note: pen.fonts.semibold(lines.size), legal: pen.fonts.mono(lines.size) }
        colors = { heading: pen.palette.cream, subheading: pen.palette.gain, note: pen.palette.cream, legal: pen.palette.cream }
        lines.visible(offset, window.height, page.line).each do |row|
          font = fonts.fetch(row.kind)
          pen.text(row.text, font, window.x + (font.width(row.text) / 2.0), window.y + row.y - offset, colors.fetch(row.kind))
        end
        G.scissor = nil
      end

      # The page's place in the window, a thin bar at the window's right
      # edge, when there is more page than window.
      def bar(scroll, window, layout)
        thumb = scroll.thumb or return
        start, length = thumb
        pixels = pen.pixels
        width = pixels.line_width(3)
        x = [pixels.snap(window.right + (layout.margin * 0.4)), layout.safe.right - width].min
        pen.color(pen.palette.soft, 0.5)
        G.rectangle(:fill, x, pixels.snap(window.y + (window.height * start)), width,
                    [pixels.snap(window.height * length), width].max, width / 2.0, width / 2.0, 8)
      end
    end
  end
end
