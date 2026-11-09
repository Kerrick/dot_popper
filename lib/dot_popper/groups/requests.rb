# frozen_string_literal: true

module DotPopper
  module Groups
    # One thing a request carries: what it is, and which store label it
    # counts under (Privacy::STORE_LABELS).
    Field = Data.define(:what, :label)

    # What one kind of job asks the server for, and everything it sends:
    # its +verb+ and +path+ (":id" for the group's), its +body+ and +query+
    # fields, whether it sends the player's +token+, and when it +happens+.
    # Session's jobs are made from these, so a job cannot go out undeclared
    # and doc/privacy.json is generated from what the game really does.
    class Request < Data.define(:kind, :verb, :path, :query, :body, :token, :happens)
      def initialize(kind:, verb:, path:, happens:, query: {}, body: {}, token: true) = super

      def path_for(group_id) = path.sub(":id", group_id.to_s)

      def labels = [*(body.values + query.values).map(&:label), *(:user_id if token)]
    end

    # Every request the game makes. Add one here and doc/privacy.json says
    # so; test/privacy/requests_test.rb sends each and reads the wire.
    REQUESTS = [
      Request.new(kind: :player, verb: :post, path: "/player", token: false,
                  happens: "The first time this device creates or joins a group: the game asks the server for an anonymous token."),
      Request.new(kind: :groups, verb: :get, path: "/groups",
                  happens: "At launch and when the groups' screen opens, once this device has a token."),
      Request.new(kind: :create, verb: :post, path: "/groups",
                  happens: "When the player creates a group."),
      Request.new(kind: :join, verb: :post, path: "/memberships",
                  body: { join_code: Field.new(what: "the code of the group to join, which the player taps in", label: :gameplay_content) },
                  happens: "When the player joins a group with a code."),
      Request.new(kind: :group, verb: :get, path: "/groups/:id",
                  happens: "When the player opens a group."),
      Request.new(kind: :changes, verb: :get, path: "/groups/:id/title_changes",
                  happens: "When the player opens a group, and whenever a group's title looks different from when it was last read."),
      Request.new(kind: :left, verb: :delete, path: "/groups/:id/membership",
                  happens: "When the player holds Leave on a group."),
      Request.new(kind: :deleted, verb: :delete, path: "/player",
                  happens: "When the player holds the delete control (see deletion)."),
      Request.new(kind: :cabinet, verb: :post, path: "/games",
                  body: { score: Field.new(what: "the score of a game that counts: played by a group member, with dots sized to the screen, not the tutorial's", label: :gameplay_content) },
                  happens: "After a game that counts, or at the next contact if it could not be sent then, while the player is in a group."),
      Request.new(kind: :themes, verb: :get, path: "/themes", token: false,
                  query: { started_on: Field.new(what: "the date this device first played", label: :other_usage) },
                  happens: "When the game is online, to learn which themes are available; for every player, Free too, with no token.")
    ].to_h { [it.kind, it] }.freeze

    # Declared and in the privacy manifest, but not yet in the game's code.
    # test/privacy/requests_test.rb fails as soon as one is built, so it
    # cannot go out unplayed.
    UNBUILT_REQUESTS = %i[themes].freeze
  end
end
