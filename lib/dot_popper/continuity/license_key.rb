# frozen_string_literal: true

module DotPopper
  module Continuity
    # A license key: what a website purchase of Pro sends by email. Version
    # 1 is 81 bytes: the version, a random 16-byte +id+, and a license-
    # signing key's Ed25519 +signature+ over LABEL and those first 17
    # bytes, so the game checks it by itself, offline, against the keys its
    # Pins trust. As text it is "DP-" and Crockford base32 in groups of
    # five; reading it ignores case, spaces, line breaks and hyphens, reads
    # O as 0 and I or L as 1, and takes it with or without "DP-", as a key
    # pasted from an email may come any of those ways.
    class LicenseKey < Data.define(:id, :signature)
      VERSION = 1
      LABEL = Continuity.label("dot-popper/license-key/v1")
      ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
      PREFIX = "DP"
      SIZE = 81
      LETTERS = 130 # 81 bytes, 648 bits, in fives, the last padded with zeros
      GROUP = 5

      # The key written in +text+, or nil when it is not one (it may still
      # not verify: #valid?).
      def self.parse(text)
        letters = text.to_s.upcase.delete(" \t\r\n-").tr("OIL", "011")
        letters = letters.delete_prefix(PREFIX) if letters.size == LETTERS + PREFIX.size
        return nil unless letters.size == LETTERS && letters.count(ALPHABET) == LETTERS

        bits = letters.chars.map { ALPHABET.index(it).to_i.to_s(2).rjust(5, "0") }.join
        return nil unless bits.end_with?("00")

        bytes = [bits[0, SIZE * 8]].pack("B*")
        return nil unless bytes.getbyte(0) == VERSION

        new(id: bytes[1, 16].to_s, signature: bytes[17, 64].to_s)
      end

      # A key for a fresh random id, signed by +seed+: the test build's
      # fake seller's (TestKeys::LICENSE).
      def self.issue(seed, id: Random.bytes(16))
        new(id:, signature: Ed25519.sign(seed, LABEL + [VERSION].pack("C") + id))
      end

      def bytes = [VERSION].pack("C") + id + signature

      def text
        bits = "#{bytes.unpack1("B*")}00"
        "#{PREFIX}-#{bits.scan(/.{5}/).map { ALPHABET[it.to_i(2)] }.join.scan(/.{1,#{GROUP}}/o).join("-")}"
      end

      # Whether a license-signing key that +pins+ trust signed it.
      def valid?(pins = PINNED) = pins.license_keys.any? { Ed25519.verify(it, signature, LABEL + bytes[0, 17].to_s) }
    end
  end
end
