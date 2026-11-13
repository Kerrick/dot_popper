# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Credits and licenses, over Settings (CreditsLayout): the text of
      # +notices+ and the game's own, which scrolls, and Back.
      class Credits < Page
        def initialize(show, notices:)
          super(show)
          @notices = notices
          @scroll = nil
          @lines = nil
          @book = nil
        end

        # How far down it is scrolled (CreditsScroll), while it is open.
        attr_accessor :scroll

        # Opens over Settings, at the top.
        def open
          return unless show.settings?

          show.open_page(:credits)
          @scroll = CreditsScroll.at_top(content: 0.0, window: 0.0)
          lay_out
        end

        # As Home shows: nothing of it is open.
        def forget = @scroll = nil

        # What it says (CreditsText), composed once.
        def book = (@book ||= CreditsText.compose(words, @notices))

        # Where its heading and its window of text go.
        def plan
          page = CreditsLayout.new(layout:, style: style::CREDITS)
          page.with(wanted: CreditsLines.widest_as_written(book, size: page.text_size, measure:))
        end

        # Its lines (CreditsLines), laid out for the screen's size.
        def lines = @lines&.last

        # The text broken into lines for this screen, and the scroll kept at
        # the same place on it.
        def lay_out
          page = plan
          key = [page.text_size, page.room]
          @lines = [key, CreditsLines.set(book, size: page.text_size, room: page.room, line: style::CREDITS.line, measure:)] if @lines&.first != key
          @scroll = @scroll.fitted(content: lines.height, window: page.window.height)
        end

        def controls = [back_button]

        def scrolls? = true

        # The text is read with the left stick too, and the cursor waits.
        def stick_scrolls? = true

        def empty(_x, y, by) = show.start_scroll(by, y)
      end
    end
  end
end
