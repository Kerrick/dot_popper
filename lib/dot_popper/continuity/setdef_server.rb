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
      def initialize(link) = @link = link

      def proof(nonce) = @link.call(:get, "#{Groups::REQUESTS.fetch(:proof).path}?nonce=#{Continuity.hex(nonce)}", nil, nil)

      # +due+ is License::Due.
      def ask(due) = @link.call(:post, Groups::REQUESTS.fetch(due.kind).path, due.body, nil)
    end

    # The port to the connectivity checks: three addresses run by Apple,
    # Google and Microsoft for exactly this, each answering a fixed reply,
    # so that one answering as expected shows the internet works. #online?
    # asks them in turn and stops at the first that does. Connectivity is
    # the real adapter, by Network::Link; the test build's is FakeSetdef.
    class Connectivity
      Check = Data.define(:url, :status, :body)

      CHECKS = [
        Check.new(url: "http://captive.apple.com/hotspot-detect.html", status: 200, body: /Success/),
        Check.new(url: "http://connectivitycheck.gstatic.com/generate_204", status: 204, body: /\A\z/),
        Check.new(url: "http://www.msftconnecttest.com/connecttest.txt", status: 200, body: /\AMicrosoft Connect Test\z/)
      ].freeze

      # +link+ makes a raw Network::Link for a URL's host.
      def initialize(checks: CHECKS, link: ->(url) { Network::Link.new(url, raw: true) })
        @checks = checks
        @link = link
      end

      def online?
        require "uri"
        @checks.any? do |check|
          uri = URI(check.url)
          reply = @link.call("#{uri.scheme}://#{uri.host}:#{uri.port}").call(:get, uri.path, nil, nil)
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
