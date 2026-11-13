# frozen_string_literal: true

module DotPopper
  module Network
    # The one place the game's server's address is set: setdef's, which
    # friend groups, themes and the proof that setdef is there all use.
    # Every build, test or store, uses SERVER_URL. DOT_POPPER_SERVER names
    # another server for friend groups and themes, to try one out (empty,
    # none: the game then offers no groups and asks for no themes); the
    # proof and license keys always go to SERVER_URL. doc/privacy.json
    # says what is sent, and when.
    module Server
      SERVER_URL = "https://server.dot-popper.setdef.com"
      OVERRIDE = "DOT_POPPER_SERVER"

      # The server for the settings +env+ (Build.settings, so a store
      # build ignores DOT_POPPER_SERVER). An automated run (Automation)
      # has no server unless it names a local fake.
      def self.server_url(env)
        fallback = Automation.on?(env) ? "" : SERVER_URL
        env.fetch(OVERRIDE, fallback).then { it.empty? ? nil : it }
      end
    end

    # The old name, until no commit uses it.
    Settings = Server
  end
end
