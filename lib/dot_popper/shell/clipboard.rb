# frozen_string_literal: true

module DotPopper
  module Shell
    # The system's clipboard, for the share preview's Copy. A clipboard
    # that will not take the text loses it, never the game.
    class Clipboard < Data.define
      def copy(text)
        ::Lota::System.clipboard_text = text
      rescue StandardError => e
        warn "Dot Popper: could not copy to the clipboard: #{e.message}"
      end
    end
  end
end
