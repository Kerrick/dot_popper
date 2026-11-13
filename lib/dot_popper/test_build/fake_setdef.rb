# frozen_string_literal: true

module DotPopper
  module Continuity
    module SignedAnswers
      module_function

      # What the test build's fake server answers (FakeSetdef), signed by
      # the test keys.
      def signed_proof(nonce)
        { "nonce" => Continuity.hex(nonce), "signature" => Continuity.hex(Ed25519.sign(TestKeys::ONLINE, PROOF + nonce)),
          "certificate" => Continuity.hex(TestKeys.online_certificate) }
      end

      def signed_verdict(verdict, id, nonce)
        { "key_id" => Continuity.hex(id), "verdict" => verdict, "nonce" => Continuity.hex(nonce),
          "signature" => Continuity.hex(Ed25519.sign(TestKeys::ONLINE, verdict_message(verdict, id, nonce))),
          "certificate" => Continuity.hex(TestKeys.online_certificate) }
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
