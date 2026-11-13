# frozen_string_literal: true

module DotPopper
  module Continuity
    # The port to setdef's own server, for what only it can answer: the
    # proof that it is itself (GET /proof) and where a license key is
    # (POST /licenses, POST /license_checks). Each answers a Network::Reply.
    # SetdefServer is the adapter for the real one, by Network::Link;
    # FakeSetdef the test build's. A replacement server is never asked any
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
    # the real adapter, by Network::Link; the test build's is FakeSetdef.
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

    # setdef's server and the internet as a test build has them: in this
    # process, with nothing sent anywhere, signing with the test keys, so
    # everything above the ports runs as it would for real. +mode+, a
    # developer's (DOT_POPPER_FAKE_SETDEF, test builds only, never on a
    # screen), says how they are: :here (setdef answers), :gone (setdef
    # gives no proof while the internet works), :offline (nothing answers)
    # or :moved (setdef answers that every key has moved elsewhere). The
    # +ledger+ (read, write) keeps what the server would: each key id's
    # SHA-256 of its device's secret.
    class FakeSetdef
      MODES = %i[here gone offline moved].freeze
      SETTING = "DOT_POPPER_FAKE_SETDEF"

      def self.mode(env) = env.fetch(SETTING, "").to_sym.then { MODES.include?(it) ? it : :here }

      def initialize(ledger, mode: :here)
        @ledger = ledger
        @mode = mode
      end

      def proof(nonce)
        return Network::Reply.offline if %i[gone offline].include?(@mode)

        Network::Reply.new(status: 200, body: SignedAnswers.signed_proof(nonce))
      end

      def online? = @mode != :offline

      def ask(due)
        return Network::Reply.offline if %i[gone offline].include?(@mode)

        due.kind == :license_entry ? enter(due.body) : check(due.body)
      end

      private

      def enter(body)
        key = LicenseKey.parse(body[:key])
        return Network::Reply.new(status: 422, body: {}) unless key&.valid?(TEST_PINS)

        remember(key.id, body[:secret])
        verdict("current", key.id, body[:nonce])
      end

      def check(body)
        id = Continuity.unhex(body[:key_id], 16)
        held = id && ledger[Continuity.hex(id)]
        return Network::Reply.new(status: 404, body: {}) unless held
        return verdict("moved", id, body[:nonce]) if @mode == :moved

        if held == digest(body[:secret]) then remember(id, body[:next])
        elsif held != digest(body[:next]) then return verdict("moved", id, body[:nonce])
        end
        verdict("current", id, body[:nonce])
      end

      def verdict(word, id, nonce) = Network::Reply.new(status: 200, body: SignedAnswers.signed_verdict(word, id, Continuity.unhex(nonce, 32).to_s))

      def digest(hex) = Continuity.hex(Ed25519.sha256(Continuity.unhex(hex, 32).to_s))

      def ledger = @ledger.read.to_s.lines.to_h { it.split.first(2) }

      def remember(id, secret)
        held = ledger.merge(Continuity.hex(id) => digest(secret))
        @ledger.write(held.map { |key_id, digest| "#{key_id} #{digest}\n" }.join)
      end
    end
  end
end
