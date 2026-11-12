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

    # The throwaway key the test build's fake store signs with, public on
    # purpose, as Continuity::TestKeys are: nothing it signs verifies in a
    # store build.
    module TestKey
      PRIVATE = <<~PEM
        -----BEGIN PRIVATE KEY-----
        MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDP/FyDSXfe7NGr
        1xaTkrw2wLTI06CJ0/tOl/AVEN9UEY+L/+Pl4r0RHYBCit09XBUcc56+XsHRmIOA
        TAT303QFBCG3sicglVRoPpx+C/OpSn3Cq+4yL8MN7hM+or/eHM1koqlIyn2f08YC
        NX/zSNhTQgakG6/B6H8S9uBhfTz4T1GdvBP9AN0orWLVkahkCsgjE+JfBHP4jKA0
        u0CTud8FukHvLe/2MbiG1Dg5tAxg2xIMY7Psj7csNhsFoAHXHkVmIitrw8NW4PI2
        Hfl35dky1AQSx5I13q72qfIOWEKEIYBPx+icz8aL166i0gZcFGREUxc5+oqX4k5t
        226bM937AgMBAAECggEAVLvvxN0NpRi+Y1ABtqW1YGkqPhdZ9E0UuXRVL3/sPIfa
        /6KE6odxl6N5OaLxd6ooP6srJUvdktKb4I0YCQ9w2QpR4lEGd9Pey4mWoBOmdXYP
        vlvlczTaNrajyITtvkPlufY7GZjFjXPt28CIHEm1OFZR9lIBTPK3srY5u/4V9OM/
        ypreWe4JfH5eaKnf+RVYCsEJUGzbaR4VVYOdU9i1ecjj0IMuzdfRzn+Dr8tNqwJb
        GjLKQH9LRFVk4J+5cjk7vbJ9bX1KUVIhvlUdqT/nby/KneH5tN3KUdKVG7O4CfZB
        p3IHjzEczt/lGEV/2oUuoi2FDVmcclD4XCsrh+n3oQKBgQDo2v98Faj/u+UR05QP
        0xqRuZcvl/NJRIPrBf6AQwjgD4rMZ08+jybRIaBryaxDqY9se3yghr2IHopexpTl
        WMa5m8Iiyllztvj55E6N2pbRkUa/7InQpSaehW6B4NjLRkDljtn3PDfPce9NViQW
        2RqcFWQWbxrKNoGaLvpCYw6QvwKBgQDkqI4Z/HizLNAJJTHwv167fiYFpHPi90oJ
        QQ982+2eLO3wPm9wsVf+sO9biSki5drLc9obw+wS3kLoVO/I59x0mQhyLPPOFa5V
        +Imeo24WoqvkaBYG/l9TSy2kRrnDbl7myhlAfGR1Wzbs5kEq/tfKfZebK5xZhVah
        U79jL8VFxQKBgAWRTvCJmAvdU0HU3EJwmr8HP/0sVe3XjIvvDcHFWI368SeoBLYL
        ODNh6XMKVGsdv8cpQLaZ4ihCCq7vcpn1QHMprT+ltPPWWSeodNRheJ+0KIvoPPdX
        K5A4woaqeKSLnnueqcmGkBMOt1kTCTPepws6W7VJnMte+ERWgTdbJPsDAoGAQsW+
        CXSiwp/5eFI2TTl1LodeDxPBC6xvIFixbyLCNwijyx5QaLZBHg0JOM/LBXfd9r+0
        F5uVGsVxAGudQiwDQsFVqBHceHf4Wv6jIYJUKaQDUkXa+NvbdnVjtK86nAllCTxH
        N3+bznF+jpuGuEmHNoiKdzO7CqFXdPEB2LMghokCgYEAm8COafbcefaMHxEqQhQp
        lIPZYORzXAUB6MLhNdQ1uOLbB/Mcoc8RhGMEMJOgiJhppWREEenegcrpZXL/Zng4
        YksZs0m0o3qV3eq8VmInwKFIrCDR0I2zvDMjmOuG8nTJY04KHuVAi2FY0VT1QYBr
        fdObkZwZ2Txfxb+pn1mWLZ0=
        -----END PRIVATE KEY-----
      PEM
      PUBLIC = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz/xcg0l33uzRq9cWk5K8NsC0yNOgidP7TpfwFRDfVBGPi//j5eK9ER2A" \
               "QordPVwVHHOevl7B0ZiDgEwE99N0BQQht7InIJVUaD6cfgvzqUp9wqvuMi/DDe4TPqK/3hzNZKKpSMp9n9PGAjV/80jYU0IGpBuv" \
               "weh/EvbgYX08+E9RnbwT/QDdKK1i1ZGoZArIIxPiXwRz+IygNLtAk7nfBbpB7y3v9jG4htQ4ObQMYNsSDGOz7I+3LDYbBaAB1x5F" \
               "ZiIra8PDVuDyNh35d+XZMtQEEseSNd6u9qnyDlhChCGAT8fonM/Gi9euotIGXBRkRFMXOfqKl+JObdtumzPd+wIDAQAB"
    end

    # What a store build trusts: Apple's root, and the app's Play key once
    # pinned.
    STORES = Trust.new(apple_roots: [APPLE_ROOT_G3].freeze, play_keys: PLAY_KEYS.map { it.unpack1("m") }.freeze,
                       app_id: APP_ID, product_id: PRODUCT_ID, windows_license: false)
    # What the Microsoft Store build trusts: Windows' word for its license,
    # and nothing that is signed, since no other store sells that build.
    MICROSOFT_STORE = Trust.new(apple_roots: [].freeze, play_keys: [].freeze, app_id: APP_ID, product_id: PRODUCT_ID,
                                windows_license: true)
    # What a test build trusts: only the fake store's test key.
    TEST = Trust.new(apple_roots: [].freeze, play_keys: [TestKey::PUBLIC.unpack1("m")].freeze, app_id: APP_ID, product_id: PRODUCT_ID,
                     windows_license: false)
  end
end
