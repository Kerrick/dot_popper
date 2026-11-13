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

    # setdef's own four public keys: the proof roots (main, and a sealed
    # backup; root ids 8336ad85d326749b and ad88ca8070d052b7) and the
    # license-signing keys (main and backup).
    SETDEF_PINS = Pins.of(
      roots: %w[79d5734924f1f17b86eec3d20cb05bcd88996cdac0ade9e76652e23890b0936b
                acc38f5061fb9de2b57dff17f2f6c51ca585b96261805a5323b1022607c82253],
      license_keys: %w[779da5ce8b28fb9486667d610482a6abd416f94cc19721f3d1313475ea7b17c2
                       e40183ecb2bfcd2ff8f124d33a0ab32d8e96749a517a07d2237a88bacea908d0]
    )

    # What a build for sale trusts: setdef's real keys.
    PINNED = SETDEF_PINS

    # The keys a build for +channel+ (Build::CHANNEL) trusts, by the
    # channel alone and never by anything set at run time (ADR-0010):
    # setdef's in a build for sale. script/check_build.rb asks this of
    # each.
    def self.pins_for(_channel) = PINNED

    # Whether +pins+ are setdef's real keys, so the server may be asked.
    def self.live?(pins = PINNED) = pins.equal?(SETDEF_PINS)
  end
end
