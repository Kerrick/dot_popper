# frozen_string_literal: true

module DotPopper
  # A store's signed record of a purchase of Pro, which the game checks by
  # itself, offline, each time the store hands it one (ADR-0010).
  # Nothing the game writes can stand in for
  # one: an edited file, a saved yes or a number never verifies.
  #
  # The app's host passes a receipt to the game as text, in one of three
  # forms, after the store's own name:
  #
  #   apple:<JWS>                 StoreKit 2's signed transaction
  #                               (VerificationResult#jwsRepresentation),
  #                               ES256, certified up to Apple Root CA - G3
  #   play:<JSON>:<signature>     Play Billing's purchase: its original JSON
  #                               and its RSA signature (PKCS #1 v1.5,
  #                               SHA-1) by the app's own Play key, both in
  #                               standard Base64
  #   microsoft:<token>:<SKU>     the Microsoft Store's license for the
  #                               add-on, which is Windows' word and no
  #                               signature (Microsoft), taken only by the
  #                               Microsoft Store build
  #
  # The test build's fake store signs "play:" receipts with a test key
  # (TestKey), which only TEST trusts. Anything that goes wrong is a receipt
  # that does not verify, never an error.
  module Receipt
    # What a build accepts a receipt from: the +apple_roots+ (DER
    # certificates) a StoreKit transaction must chain to, the +play_keys+
    # (DER public keys) a Play purchase must be signed by, the app's
    # +app_id+ (its bundle ID and package name) and the +product_id+, and
    # whether Windows' word for a Microsoft Store license is taken
    # (+windows_license+), which only the Microsoft Store build's is.
    Trust = Data.define(:apple_roots, :play_keys, :app_id, :product_id, :windows_license)

    APP_ID = "com.setdef.DotPopper"
    PRODUCT_ID = "com.setdef.dotpopper.pro"

    # Whether +text+ is a receipt for Pro that +trust+ accepts.
    def self.valid?(text, trust)
      store, rest = text.to_s.strip.split(":", 2)
      case store
      when "apple" then Apple.valid?(rest.to_s, trust)
      when "play" then Play.valid?(rest.to_s, trust)
      when "microsoft" then Microsoft.valid?(rest.to_s, trust)
      else false
      end
    end

    # OpenSSL and JSON, loaded on first use, as Continuity::Ed25519 does,
    # so a game that is never handed a receipt never loads them.
    def self.load_openssl
      require "openssl"
      require "json"
    end
  end
end

# Apple's and Play's checks and the test key need OpenSSL and JSON, and
# are left out of the rules' type check (Steepfile).
%w[apple play microsoft pins].each { require_relative "receipt/#{it}" }
