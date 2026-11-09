# frozen_string_literal: true

module DotPopper
  module Groups
    # The one place the server's address is set. While it is nil, the game
    # offers no groups at all and makes no network connection;
    # DOT_POPPER_SERVER names another server, to try one out (empty, none).
    # A test build (one with no store channel, Presentation::Storefront
    # .test_build?) uses TEST_SERVER_URL; a store build uses SERVER_URL,
    # which stays nil until the maintainer says otherwise.
    module Settings
      SERVER_URL = nil
      TEST_SERVER_URL = "https://server.dot-popper.setdef.com"
      OVERRIDE = "DOT_POPPER_SERVER"

      def self.server_url(env = ENV, test_build: false)
        env.fetch(OVERRIDE) { test_build ? TEST_SERVER_URL : SERVER_URL }&.then { it.empty? ? nil : it }
      end
    end
  end
end
