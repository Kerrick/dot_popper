# frozen_string_literal: true

module DotPopper
  module Continuity
    # A setdef certificate (the server's docs/api.md, "Bytes"): 141 bytes in
    # which one of the pinned roots vouches for a key, for one purpose. It
    # has no expiry. The server's online key is certified for PROOF, and
    # signs both proofs and license answers with it.
    class Certificate < Data.define(:root_id, :purpose, :public_key)
      SIZE = 141
      MAGIC = "DPCT".b
      VERSION = 1
      SIGNING_LABEL = Continuity.label("dot-popper/certificate/v1")
      PROOF = Continuity.label("dot-popper/server-proof/v1")

      # The first 8 bytes of the SHA-256 of +root+, as a certificate names it.
      def self.id_of(root) = Ed25519.sha256(root)[0, 8].to_s

      # The certificate in +bytes+ if it is whole, for +purpose+, and signed
      # by one of +roots+ (32-byte public keys); otherwise nil. A key taken
      # from the certificate is never used as a root.
      def self.verified(bytes, roots:, purpose:)
        bytes = bytes.to_s.b
        return nil unless bytes.bytesize == SIZE && bytes[0, 4] == MAGIC && bytes.getbyte(4) == VERSION && bytes[13, 32] == purpose

        root = roots.find { id_of(it) == bytes[5, 8] } or return nil
        return nil unless Ed25519.verify(root, bytes[77, 64].to_s, SIGNING_LABEL + bytes[0, 77].to_s)

        new(root_id: bytes[5, 8], purpose:, public_key: bytes[45, 32])
      end

      # A certificate for +public_key+ signed by +root_seed+, for the test
      # build's fakes (TestKeys).
      def self.issue(root_seed, purpose, public_key)
        body = MAGIC + [VERSION].pack("C") + id_of(Ed25519.public_key(root_seed)) + purpose + public_key
        body + Ed25519.sign(root_seed, SIGNING_LABEL + body)
      end
    end
  end
end
