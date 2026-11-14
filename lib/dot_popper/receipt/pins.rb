# frozen_string_literal: true

module DotPopper
  module Receipt
    # Apple Root CA - G3, from https://www.apple.com/certificateauthority/
    # (SHA-256 63343ABF B89A6A03 EBB57E9B 3F5FA7BE 7C4F5C75 6F3017B3
    # A8C488C3 653E9179), which certifies StoreKit 2's signed transactions.
    APPLE_ROOT_G3 = <<~BASE64.unpack1("m").freeze
      MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v
      dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE
      CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2
      WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj
      YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG
      SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE
      tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC
      MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P
      AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m
      eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL
      F1vLUagM6BgD56KyKA==
    BASE64

    # The app's public key from the Play Console (Monetize, Monetization
    # setup, Licensing), Base64 as the Console shows it. Empty until the
    # maintainer pins it, so until then no Google Play purchase verifies;
    # script/check_build.rb fails a Google Play build while it is.
    PLAY_KEYS = [].freeze


    # What a store build trusts: Apple's root, and the app's Play key once
    # pinned.
    STORES = Trust.new(apple_roots: [APPLE_ROOT_G3].freeze, play_keys: PLAY_KEYS.map { it.unpack1("m") }.freeze,
                       app_id: APP_ID, product_id: PRODUCT_ID, windows_license: false)
    # What the Microsoft Store build trusts: Windows' word for its license,
    # and nothing that is signed, since no other store sells that build.
    MICROSOFT_STORE = Trust.new(apple_roots: [].freeze, play_keys: [].freeze, app_id: APP_ID, product_id: PRODUCT_ID,
                                windows_license: true)
  end
end
