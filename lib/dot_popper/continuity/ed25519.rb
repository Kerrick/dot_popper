# frozen_string_literal: true

module DotPopper
  module Continuity
    # Ed25519 (RFC 8032, pure) by Ruby's OpenSSL, which every build carries:
    # Fledge's desktop runtimes (rv-ruby's, and RubyInstaller's on Windows)
    # and its iOS and Android runtimes link OpenSSL 3, which has Ed25519
    # (ADR-0011). openssl is required on
    # first use, so a game that never checks a key never loads it. Anything
    # that goes wrong is a signature that does not verify, never an error.
    module Ed25519
      # The DER prefixes of a raw 32-byte public key (SubjectPublicKeyInfo)
      # and a raw 32-byte private seed (PKCS #8), as OpenSSL reads them.
      PUBLIC_DER = ["302a300506032b6570032100"].pack("H*").freeze
      PRIVATE_DER = ["302e020100300506032b657004220420"].pack("H*").freeze

      module_function

      # Whether +signature+ (64 bytes) is +public_key+'s (32 bytes) over
      # +message+.
      def verify(public_key, signature, message)
        return false unless public_key.bytesize == 32 && signature.bytesize == 64

        require "openssl"
        OpenSSL::PKey.read(PUBLIC_DER + public_key.b).verify(nil, signature.b, message.b)
      rescue StandardError, ScriptError
        false
      end

      # +seed+'s (32 bytes) signature over +message+. Only the test build's
      # fakes sign (TestKeys); the game itself never holds a real private key.
      def sign(seed, message)
        require "openssl"
        OpenSSL::PKey.read(PRIVATE_DER + seed.b).sign(nil, message.b)
      end

      # The public key of +seed+.
      def public_key(seed)
        require "openssl"
        OpenSSL::PKey.read(PRIVATE_DER + seed.b).public_to_der[-32..].to_s
      end

      # Whether this Ruby verifies Ed25519 at all: the server's published
      # test vector (its docs/api.md) checks out. Where it can't, a failed
      # proof proves nothing, and setdef is never found gone.
      def available?
        key = ["4b27a311e0ca69f749672766d988b3e673d347bfcd7f67aeff856ff743fe036d"].pack("H*")
        signature = ["4523c24b7b106e8207bea434ddb355d0898f0c60a0edf8bc8593fd4f17ac9373" \
                     "f548ce3f7f5e96fd9f90ce455cdb93c196c4f1f96b82d7374ef7698dd2942004"].pack("H*")
        message = Continuity.label("dot-popper/server-proof/v1") + (0..31).to_a.pack("C*")
        verify(key, signature, message)
      end

      def sha256(bytes)
        require "digest"
        Digest::SHA256.digest(bytes.b)
      end
    end

    # ASCII +text+ padded on the right with zero bytes to 32, as every
    # label and purpose in setdef's signed messages is (the server's
    # docs/api.md).
    def self.label(text) = text.b.ljust(32, "\0".b).freeze

    def self.hex(bytes) = bytes.unpack1("H*")

    # +text+'s bytes when it is lowercase hex of +size+ bytes, else nil.
    def self.unhex(text, size)
      return nil unless text.is_a?(String) && text.match?(/\A[0-9a-f]{#{size * 2}}\z/)

      [text].pack("H*")
    end
  end
end
