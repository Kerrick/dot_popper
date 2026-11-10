# frozen_string_literal: true

module DotPopper
  module Continuity
    # The private seeds behind TEST_PINS, made for this purpose and public
    # on purpose: the test build's fakes sign with them, so a key the fake
    # seller issues and an answer the fake server gives verify by the very
    # code a real one does. Nothing signed by them is trusted once PINNED
    # is setdef's real keys.
    module TestKeys
      ROOT = ["67191f818614ee7f90d9da198e38e9476e5b56ef3be77cb62b18081c8c10e5b6"].pack("H*").freeze
      LICENSE = ["a32a9625168379d464511c036f8d3366c9535dead19aa8b80372034e07d7e6c2"].pack("H*").freeze
      ONLINE = ["b4452db4d792a54c54b4ba6ef820e608af96cd3572a5c1411efa16a592e7281f"].pack("H*").freeze

      # The online key's certificate, by the test root.
      def self.online_certificate
        @online_certificate ||= Certificate.issue(ROOT, Certificate::PROOF, Ed25519.public_key(ONLINE)).freeze
      end
    end
  end
end
