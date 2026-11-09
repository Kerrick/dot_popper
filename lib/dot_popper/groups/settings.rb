# frozen_string_literal: true

module DotPopper
  module Groups
    # The one place the server's address is set. Every build, test or store,
    # uses SERVER_URL; DOT_POPPER_SERVER names another server, to try one
    # out (empty, none, and the game then offers no groups and makes no
    # network connection). Nothing is sent until a Pro player creates or
    # joins a group (doc/publishing.md says what then).
    module Settings
      SERVER_URL = "https://server.dot-popper.setdef.com"
      OVERRIDE = "DOT_POPPER_SERVER"

      def self.server_url(env = ENV)
        env.fetch(OVERRIDE, SERVER_URL).then { it.empty? ? nil : it }
      end
    end
  end
end
