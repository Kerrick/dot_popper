# frozen_string_literal: true

module DotPopper
  module Groups
    # The one place the server's address is set. While it is nil, the game
    # offers no groups at all and makes no network connection;
    # DOT_POPPER_SERVER names another server, to try one out.
    module Settings
      SERVER_URL = nil
      OVERRIDE = "DOT_POPPER_SERVER"

      def self.server_url(env = ENV) = env.fetch(OVERRIDE, SERVER_URL)&.then { it.empty? ? nil : it }
    end
  end
end
