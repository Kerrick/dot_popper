# frozen_string_literal: true

module DotPopper
  module Groups
    # A friend groups request: it sends the player's token unless it says
    # otherwise.
    def self.request(token: true, **) = Network::Request.new(feature: "friend groups", token:, **)
    private_class_method :request

    # Every request friend groups make; Session's jobs are made only from
    # these (Session::Job.of). Add one here and doc/privacy.json says so
    # (Privacy::REQUESTS); test/privacy/requests_test.rb sends each and
    # reads the wire.
    REQUESTS = [
      request(kind: :player, verb: :post, path: "/player", token: false,
              happens: "The first time this device creates or joins a group: the game asks the server for a private code."),
      request(kind: :groups, verb: :get, path: "/groups",
              happens: "At launch and when the groups' screen opens, once this device has a private code. #{Refresh::HAPPENS}"),
      request(kind: :create, verb: :post, path: "/groups",
              happens: "When the player creates a group."),
      request(kind: :join, verb: :post, path: "/memberships",
              body: { join_code: Network::Field.new(what: "the code of the group to join, which the player taps in", label: :gameplay_content) },
              happens: "When the player joins a group with a code."),
      request(kind: :group, verb: :get, path: "/groups/:id",
              happens: "When the player opens a group."),
      request(kind: :history, verb: :get, path: "/groups/:id/history",
              happens: "When the player opens a group or its history, and whenever a group's title looks different from when it was last read."),
      request(kind: :achievement, verb: :post, path: "/achievements",
              body: { key: Network::Field.new(what: "which achievement a Pro player earned, for their friend groups' history", label: :gameplay_content) },
              happens: "When a Pro player in a friend group earns an achievement, once for each, and on buying Pro for those already earned."),
      request(kind: :left, verb: :delete, path: "/groups/:id/membership",
              happens: "When the player holds Leave on a group."),
      request(kind: :deleted, verb: :delete, path: "/player",
              happens: "When the player holds the delete control (see deletion)."),
      request(kind: :game, verb: :post, path: "/games",
              body: { score: Network::Field.new(what: "the score of a game that counts: played by a group member, not the tutorial's", label: :gameplay_content) },
              happens: "After a game that counts, or at the next contact if it could not be sent then, while the player is in a group.")
    ].to_h { [it.kind, it] }.freeze
  end
end
