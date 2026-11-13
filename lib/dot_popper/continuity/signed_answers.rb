# frozen_string_literal: true

module DotPopper
  module Continuity
    # The answers setdef's server signs with its online key, which a pinned
    # root certifies (Certificate::PROOF). An answer that fails any check
    # is no answer at all.
    module SignedAnswers
      PROOF = Certificate::PROOF
      LICENSE = Continuity.label("dot-popper/license-check/v1")
      VERDICTS = { "current" => 1, "moved" => 0 }.freeze

      module_function

      # 32 fresh bytes from a secure source: a nonce, or a device's secret.
      def fresh
        require "securerandom"
        SecureRandom.bytes(32)
      end

      # Whether +body+ (the parsed JSON of a 200 from GET /proof) proves
      # setdef's server answered +nonce+ (the server's docs/api.md,
      # "Verifying, in the game").
      def proof?(body, nonce, pins = PINNED)
        return false unless body.is_a?(Hash) && body["nonce"] == Continuity.hex(nonce)

        key = online_key(body, pins) or return false
        signature = Continuity.unhex(body["signature"], 64) or return false
        Ed25519.verify(key, signature, PROOF + nonce)
      end

      # The verdict, :current or :moved, that +body+ (the parsed JSON of a
      # 200 from POST /licenses or /license_checks) signs for the license
      # key +id+ in answer to +nonce+, or nil.
      def verdict(body, id, nonce, pins = PINNED)
        return nil unless body.is_a?(Hash) && VERDICTS.key?(body["verdict"]) && body["nonce"] == Continuity.hex(nonce)
        return nil unless body["key_id"] == Continuity.hex(id)

        online = online_key(body, pins) or return nil
        signature = Continuity.unhex(body["signature"], 64) or return nil
        Ed25519.verify(online, signature, verdict_message(body["verdict"], id, nonce)) ? body["verdict"].to_sym : nil
      end

      def verdict_message(verdict, id, nonce) = LICENSE + nonce + id + [VERDICTS.fetch(verdict)].pack("C")

      def online_key(body, pins)
        bytes = Continuity.unhex(body["certificate"], Certificate::SIZE) or return nil
        Certificate.verified(bytes, roots: pins.roots, purpose: PROOF)&.public_key
      end
    end
  end
end
