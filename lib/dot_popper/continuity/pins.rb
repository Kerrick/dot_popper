# frozen_string_literal: true

module DotPopper
  module Continuity
    # The keys a build trusts, pinned in its code, since a shipped copy can
    # never learn new ones: the +roots+ that certify the server's online
    # key (GET /proof and license answers), and the +license_keys+ that
    # sign license keys, each the main one and a sealed backup, as 32-byte
    # Ed25519 public keys. Nothing a server sends can add to them.
    class Pins < Data.define(:roots, :license_keys)
      def self.of(roots:, license_keys:)
        new(roots: roots.map { [it].pack("H*").freeze }.freeze, license_keys: license_keys.map { [it].pack("H*").freeze }.freeze)
      end
    end

    # Throwaway keys, made for the test build's fakes, whose private seeds
    # ship in the game (TestKeys), so they prove nothing outside a test
    # build. They stand in until setdef's real keys exist.
    TEST_PINS = Pins.of(
      roots: %w[e867ed3d37bcc7948f7c2ca7d57e7d2587dc93c53a9f6ece29f2d41bae20621b
                a52b818651332dc6c25404e5abf90809d2c7b276e00a1f265fd3980e4aaa7dad],
      license_keys: %w[e6fe40875397014384ed6d74414bbd1f645476478311f8c6061bc2772cbaca1a
                       8aac532eb028225861e7e98055f98b5e06d7586fd07fbf5c4bca51cc7d4c8d90]
    )

    # setdef's own four public keys, as hex, once they exist:
    #   Pins.of(roots: %w[MAIN_ROOT BACKUP_ROOT], license_keys: %w[MAIN BACKUP])
    SETDEF_PINS = nil

    # What this build trusts. To ship setdef's real keys, fill in
    # SETDEF_PINS and change this one line to SETDEF_PINS. While it is
    # TEST_PINS, no build asks setdef's real server anything (.live?), so
    # none can decide setdef is gone from a proof it could never verify.
    PINNED = TEST_PINS

    # Whether this build trusts real keys, and so may ask the real server.
    def self.live?(pins = PINNED) = !pins.equal?(TEST_PINS)
  end
end
