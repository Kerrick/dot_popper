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

    # setdef's own four public keys: the proof roots (main, and a sealed
    # backup; root ids 8336ad85d326749b and ad88ca8070d052b7) and the
    # license-signing keys (main and backup).
    SETDEF_PINS = Pins.of(
      roots: %w[79d5734924f1f17b86eec3d20cb05bcd88996cdac0ade9e76652e23890b0936b
                acc38f5061fb9de2b57dff17f2f6c51ca585b96261805a5323b1022607c82253],
      license_keys: %w[779da5ce8b28fb9486667d610482a6abd416f94cc19721f3d1313475ea7b17c2
                       e40183ecb2bfcd2ff8f124d33a0ab32d8e96749a517a07d2237a88bacea908d0]
    )

    # What this build trusts: setdef's real keys. A test build (no store
    # channel) trusts TEST_PINS instead, in the app, and nothing signed by
    # the test keys verifies against these. While this was TEST_PINS, no
    # build asked setdef's real server anything (.live?).
    PINNED = SETDEF_PINS

    # The keys a build for +channel+ (Build::CHANNEL) trusts, by the
    # channel alone and never by anything set at run time (ADR-0010):
    # setdef's in a store build, the test keys in a test build.
    # script/check_build.rb asks this of a build for sale.
    def self.pins_for(channel) = Build.store?(channel) ? PINNED : TEST_PINS

    # Whether this build trusts real keys, and so may ask the real server.
    def self.live?(pins = PINNED) = !pins.equal?(TEST_PINS)
  end
end
