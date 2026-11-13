# frozen_string_literal: true

module DotPopper
  module Continuity
    # The port to setdef's own server, for what only it can answer: the
    # proof that it is itself (GET /proof) and where a license key is
    # (POST /licenses, POST /license_checks). Each answers a Network::Reply.
    # SetdefServer is the adapter for the real one, by Network::Link; a
    # test build has its own (lib/dot_popper/test_build). A replacement
    # server is never asked any
    # of this: it is setdef's, whatever server friend groups use.
    class SetdefServer
      # What setdef's server is asked; #proof and #ask make requests only
      # from these.
      REQUESTS = [
        Network::Request.new(kind: :proof, verb: :get, path: "/proof", feature: "checking that setdef's server is setdef's",
                             query: { nonce: Network::Field.new(what: "32 random bytes, new for each check, which the server signs", label: :other_usage) },
                             happens: "Once each time the game starts, on copies that can check, to tell setdef's server from anyone else at its address. Always to setdef's own server, never a replacement."),
        Network::Request.new(kind: :license_entry, verb: :post, path: "/licenses", feature: "license keys",
                             body: { key: Network::Field.new(what: "the license key the player pasted", label: :license_key),
                                     secret: Network::Field.new(what: "32 random bytes this device chose, which the server keeps only as a SHA-256", label: :license_key),
                                     nonce: Network::Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                             happens: "When a player enters a license key, and at each start until setdef's server has answered, so the key moves to this device. Never on a copy sold by a store."),
        Network::Request.new(kind: :license_check, verb: :post, path: "/license_checks", feature: "license keys",
                             body: { key_id: Network::Field.new(what: "the license key's id, its first part", label: :license_key),
                                     secret: Network::Field.new(what: "this device's current secret for the key", label: :license_key),
                                     next: Network::Field.new(what: "32 random bytes this device chose as its next secret", label: :license_key),
                                     nonce: Network::Field.new(what: "32 random bytes, new for each request, which the server signs", label: :license_key) },
                             happens: "Once each time the game starts, on a device holding a license key, to learn whether the key has moved to another device.")
      ].to_h { [it.kind, it] }.freeze

      def initialize(link) = @link = link

      def proof(nonce) = @link.call(Network::Job.of(REQUESTS.fetch(:proof), query: { nonce: Continuity.hex(nonce) }), nil)

      # +due+ is License::Due.
      def ask(due) = @link.call(Network::Job.of(REQUESTS.fetch(due.kind), body: due.body), nil)
    end

    # The port to the connectivity checks: three addresses run by Apple,
    # Google and Microsoft for exactly this, each answering a fixed reply,
    # so that one answering as expected shows the internet works. #online?
    # asks them in turn and stops at the first that does. Connectivity is
    # the real adapter, by Network::Link; a test build has its own.
    class Connectivity
      # The three checks, each to its own host (+to+), as plain HTTP.
      REQUESTS = [
        Network::Request.new(kind: :connectivity_apple, verb: :get, path: "/hotspot-detect.html", to: "captive.apple.com", feature: "connectivity checks",
                             happens: "Only when setdef's server gave no valid proof at a start: to tell setdef being gone from the internet being down. Apple's connectivity check, which answers the same page to everyone."),
        Network::Request.new(kind: :connectivity_google, verb: :get, path: "/generate_204", to: "connectivitycheck.gstatic.com", feature: "connectivity checks",
                             happens: "As the one before, only if Apple's check did not answer as expected. Google's connectivity check, which answers an empty page to everyone."),
        Network::Request.new(kind: :connectivity_microsoft, verb: :get, path: "/connecttest.txt", to: "www.msftconnecttest.com", feature: "connectivity checks",
                             happens: "As the one before, only if neither Apple's nor Google's check answered as expected. Microsoft's connectivity check, which answers the same line to everyone.")
      ].to_h { [it.kind, it] }.freeze

      # A check: its declaration, and the answer that shows the internet
      # works.
      Check = Data.define(:request, :status, :body) do
        def url = "http://#{request.to}"
      end

      CHECKS = [
        Check.new(request: REQUESTS.fetch(:connectivity_apple), status: 200, body: /Success/),
        Check.new(request: REQUESTS.fetch(:connectivity_google), status: 204, body: /\A\z/),
        Check.new(request: REQUESTS.fetch(:connectivity_microsoft), status: 200, body: /\AMicrosoft Connect Test\z/)
      ].freeze

      # +link+ makes a raw Network::Link for a check's host.
      def initialize(checks: CHECKS, link: ->(url) { Network::Link.new(url, raw: true) })
        @checks = checks
        @link = link
      end

      def online?
        @checks.any? do |check|
          reply = @link.call(check.url).call(Network::Job.of(check.request), nil)
          reply.status == check.status && reply.body.is_a?(String) && reply.body.strip.match?(check.body)
        end
      end
    end
  end
end
