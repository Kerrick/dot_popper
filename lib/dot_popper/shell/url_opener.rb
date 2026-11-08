# frozen_string_literal: true

module DotPopper
  module Shell
    # Opens a URL with Lota::System.open_url (SDL_OpenURL), for
    # SheetSharing and Storefront: true if the system took it. One it will
    # not take is false, and the game shares its own way instead, or says
    # the store isn't answering.
    class UrlOpener < Data.define
      def open(url)
        ::Lota::System.open_url(url)
      rescue StandardError => e
        warn "Dot Popper: could not open #{url[/\A[^:]*/]}: #{e.message}"
        false
      end
    end
  end
end
