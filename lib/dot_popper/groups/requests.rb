# frozen_string_literal: true

module DotPopper
  module Groups
    # One thing a request carries: what it is, and which store label it
    # counts under (Privacy::STORE_LABELS).
    Field = Data.define(:what, :label)

    # What one kind of job asks the server for, and everything it sends:
    # its +verb+ and +path+ (":id" for the group's), its +body+ and +query+
    # fields, whether it sends the player's +token+, and when it +happens+.
    # +to+ is the host it goes to when that is not the game's server: the
    # connectivity checks' (Continuity::Connectivity).
    # Session's jobs are made from these, so a job cannot go out undeclared
    # and doc/privacy.json is generated from what the game really does.
    class Request < Data.define(:kind, :verb, :path, :query, :body, :token, :happens, :feature, :to)
      def initialize(kind:, verb:, path:, happens:, query: {}, body: {}, token: true, feature: "friend groups", to: nil) = super

      def path_for(group_id) = path.sub(":id", group_id.to_s)

      def labels = [*(body.values + query.values).map(&:label), *(:user_id if token)]
    end

    # Every request the game makes. Add one here and doc/privacy.json says
    # so; test/privacy/requests_test.rb sends each and reads the wire.
    REQUESTS = [
      Request.new(kind: :player, verb: :post, path: "/player", token: false,
                  happens: "The first time this device creates or joins a group: the game asks the server for a private code."),
      Request.new(kind: :groups, verb: :get, path: "/groups",
                  happens: "At launch and when the groups' screen opens, once this device has a private code."),
      Request.new(kind: :create, verb: :post, path: "/groups",
                  happens: "When the player creates a group."),
      Request.new(kind: :join, verb: :post, path: "/memberships",
                  body: { join_code: Field.new(what: "the code of the group to join, which the player taps in", label: :gameplay_content) },
                  happens: "When the player joins a group with a code."),
      Request.new(kind: :group, verb: :get, path: "/groups/:id",
                  happens: "When the player opens a group."),
      Request.new(kind: :history, verb: :get, path: "/groups/:id/history",
                  happens: "When the player opens a group or its history, and whenever a group's title looks different from when it was last read."),
      Request.new(kind: :achievement, verb: :post, path: "/achievements",
                  body: { key: Field.new(what: "which achievement a Pro player earned, for their friend groups' history", label: :gameplay_content) },
                  happens: "When a Pro player in a friend group earns an achievement, once for each, and on buying Pro for those already earned."),
      Request.new(kind: :left, verb: :delete, path: "/groups/:id/membership",
                  happens: "When the player holds Leave on a group."),
      Request.new(kind: :deleted, verb: :delete, path: "/player",
                  happens: "When the player holds the delete control (see deletion)."),
      Request.new(kind: :game, verb: :post, path: "/games",
                  body: { score: Field.new(what: "the score of a game that counts: played by a group member, with dots sized to the screen, not the tutorial's", label: :gameplay_content) },
                  happens: "After a game that counts, or at the next contact if it could not be sent then, while the player is in a group."),
      Request.new(kind: :themes, verb: :get, path: "/themes", token: false, feature: "themes",
                  query: { started_on: Field.new(what: "the date this device first played", label: :other_usage) },
                  happens: "When the game is online, to learn which themes are available; for every player, Free too, with no private code."),
      Request.new(kind: :proof, verb: :get, path: "/proof", token: false, feature: "checking that setdef's server is setdef's",
                  query: { nonce: Field.new(what: "32 random bytes, new for each check, which the server signs", label: :other_usage) },
                  happens: "Once each time the game starts, on copies that can check, to tell setdef's server from anyone else at its address. Always to setdef's own server, never a replacement."),
      Request.new(kind: :license_entry, verb: :post, path: "/licenses", token: false, feature: "license keys",
                  body: { key: Field.new(what: "the license key the player pasted", label: :license_key),
                          secret: Field.new(what: "32 random bytes this device chose, which the server keeps only as a SHA-256", label: :license_key),
                          nonce: Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                  happens: "When a player enters a license key, and at each start until setdef's server has answered, so the key moves to this device. Never on a copy sold by a store."),
      Request.new(kind: :license_check, verb: :post, path: "/license_checks", token: false, feature: "license keys",
                  body: { key_id: Field.new(what: "the license key's id, its first part", label: :license_key),
                          secret: Field.new(what: "this device's current secret for the key", label: :license_key),
                          next: Field.new(what: "32 random bytes this device chose as its next secret", label: :license_key),
                          nonce: Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                  happens: "Once each time the game starts, on a device holding a license key, to learn whether the key has moved to another device."),
      Request.new(kind: :connectivity_apple, verb: :get, path: "/hotspot-detect.html", token: false, to: "captive.apple.com", feature: "connectivity checks",
                  happens: "Only when setdef's server gave no valid proof at a start: to tell setdef being gone from the internet being down. Apple's connectivity check, which answers the same page to everyone."),
      Request.new(kind: :connectivity_google, verb: :get, path: "/generate_204", token: false, to: "connectivitycheck.gstatic.com", feature: "connectivity checks",
                  happens: "As the one before, only if Apple's check did not answer as expected. Google's connectivity check, which answers an empty page to everyone."),
      Request.new(kind: :connectivity_microsoft, verb: :get, path: "/connecttest.txt", token: false, to: "www.msftconnecttest.com", feature: "connectivity checks",
                  happens: "As the one before, only if neither Apple's nor Google's check answered as expected. Microsoft's connectivity check, which answers the same line to everyone.")
    ].to_h { [it.kind, it] }.freeze

    # Declared and in the privacy manifest, but not yet in the game's code.
    # test/privacy/requests_test.rb fails as soon as one is built, so it
    # cannot go out unplayed.
    UNBUILT_REQUESTS = %i[].freeze

    # What the game reaches its server for, in this build.
    def self.features_built = REQUESTS.values.reject { UNBUILT_REQUESTS.include?(it.kind) }.map(&:feature).uniq
  end
end
