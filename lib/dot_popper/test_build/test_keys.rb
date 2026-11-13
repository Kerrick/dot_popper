# frozen_string_literal: true

module DotPopper
  module Continuity
    # Throwaway keys, made for the test build's fakes, whose private seeds
    # ship in the test build (TestKeys), so they prove nothing outside it.
    TEST_PINS = Pins.of(
      roots: %w[e867ed3d37bcc7948f7c2ca7d57e7d2587dc93c53a9f6ece29f2d41bae20621b
                a52b818651332dc6c25404e5abf90809d2c7b276e00a1f265fd3980e4aaa7dad],
      license_keys: %w[e6fe40875397014384ed6d74414bbd1f645476478311f8c6061bc2772cbaca1a
                       8aac532eb028225861e7e98055f98b5e06d7586fd07fbf5c4bca51cc7d4c8d90]
    )

    # The private seeds behind TEST_PINS, made for this purpose and public
    # on purpose: the test build's fakes sign with them, so a key the fake
    # seller issues and an answer the fake server gives verify by the very
    # code a real one does. Nothing signed by them is trusted by a build
    # for sale, which pins setdef's real keys.
    module TestKeys
      ROOT = ["67191f818614ee7f90d9da198e38e9476e5b56ef3be77cb62b18081c8c10e5b6"].pack("H*").freeze
      LICENSE = ["a32a9625168379d464511c036f8d3366c9535dead19aa8b80372034e07d7e6c2"].pack("H*").freeze
      ONLINE = ["b4452db4d792a54c54b4ba6ef820e608af96cd3572a5c1411efa16a592e7281f"].pack("H*").freeze

      # The online key's certificate, by the test root.
      def self.online_certificate
        @online_certificate ||= Certificate.issue(ROOT, Certificate::PROOF, Ed25519.public_key(ONLINE)).freeze
      end
    end

    # A test build (no channel) trusts the test keys; a build for sale,
    # setdef's (Continuity.pins_for).
    module TestBuildPins
      def pins_for(channel) = Build.store?(channel) ? super : TEST_PINS
    end
    singleton_class.prepend(TestBuildPins)
  end
end
