# frozen_string_literal: true

module DotPopper
  module Network
    # One thing a request carries: what it is, and which store label it
    # counts under (Privacy::STORE_LABELS).
    Field = Data.define(:what, :label)

    # The declaration of one kind of request, and everything it sends: its
    # +verb+ and +path+ (":id" for the thing it is about), its +body+ and
    # +query+ fields, whether it sends the player's +token+, when it
    # +happens+, and the +feature+ it is for. +to+ is the host it goes to
    # when that is not the game's server: the connectivity checks'.
    # Each part of the game declares its own requests where it lives, and
    # makes a Job only from one, so no request goes out undeclared and
    # doc/privacy.json (Privacy::REQUESTS) is generated from what the game
    # really does.
    class Request < Data.define(:kind, :verb, :path, :query, :body, :token, :happens, :feature, :to)
      def initialize(kind:, verb:, path:, happens:, feature:, query: {}, body: {}, token: false, to: nil) = super

      def labels = [*(body.values + query.values).map(&:label), *(:user_id if token)]
    end

    # One request to make: the +verb+, the +path+ with its id and query
    # filled in, and the +body+ to send, for a Link. Made only by Job.of,
    # from a Request, which refuses any field the declaration does not
    # name, so nothing goes out that isn't declared.
    class Job < Data.define(:kind, :verb, :path, :body)
      def self.of(request, body: nil, query: nil, id: nil)
        raise ArgumentError, "#{request.kind} sends #{body.to_h.keys}, but declares #{request.body.keys}" unless body.to_h.keys == request.body.keys
        raise ArgumentError, "#{request.kind} asks #{query.to_h.keys}, but declares #{request.query.keys}" unless query.to_h.keys == request.query.keys

        path = request.path.sub(":id", id.to_s)
        new(kind: request.kind, verb: request.verb, path: query.to_h.empty? ? path : "#{path}?#{form(query)}", body:)
      end

      def self.form(query)
        require "uri"
        URI.encode_www_form(query)
      end

      private_class_method :new, :[], :form
    end
  end
end
