# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a phone offers a result to share: through the system's own share
    # sheet, which Lota cannot open. Lota opens URLs, though (SDL_OpenURL),
    # so the game opens one in its own scheme, SCHEME, with the text in
    # its query, and the app's host catches that URL before it leaves the
    # app and shows the sheet (doc/ios.md, "Share my score"): iOS's
    # UIApplication subclass, Android's MainActivity#startActivity.
    #
    # +opener+ answers open(url) with whether the URL was taken. Taken, no
    # preview opens, so #offer answers nil; refused, the result is offered
    # +fallback+'s way, the in-game preview.
    class SheetSharing < Data.define(:opener, :fallback)
      SCHEME = "dotpopper-share"
      # What a query value keeps as it is (RFC 3986's unreserved); every
      # other byte is percent-encoded, a space as %20 and a plus as %2B,
      # which both iOS's and Android's URL parsers decode alike.
      UNRESERVED = /[^A-Za-z0-9\-._~]/n

      # The sharing on +platform+ (Platform): the sheet where the phone
      # host shows one, else the in-game preview.
      def self.for(platform, opener:)
        platform.phone_host? ? new(opener:, fallback: InGameSharing.new) : InGameSharing.new
      end

      # The URL that carries +text+ to the host.
      def self.url(text)
        "#{SCHEME}://score?text=#{text.b.gsub(UNRESERVED) { format('%%%02X', it.ord) }}"
      end

      def offer(text, now) = opener.open(self.class.url(text)) ? nil : fallback.offer(text, now)
    end
  end
end
