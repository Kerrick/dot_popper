# frozen_string_literal: true

module DotPopper
  module Receipt
    # The throwaway key the test build's fake store signs with, public on
    # purpose, as Continuity::TestKeys are: nothing it signs verifies in a
    # build for sale.
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

    # What a test build trusts: only the fake store's test key.
    TEST = Trust.new(apple_roots: [].freeze, play_keys: [TestKey::PUBLIC.unpack1("m")].freeze, app_id: APP_ID, product_id: PRODUCT_ID,
                     windows_license: false)

    # A receipt for Pro in Play's form, as the test build's fake store
    # hands one over, signed by +key+ (PEM): the test key unless a test
    # says otherwise.
    def self.issue(key: TestKey::PRIVATE, app_id: APP_ID, product_id: PRODUCT_ID, state: 0, at: Time.now)
      load_openssl
      json = JSON.generate(orderId: "TEST.#{Random.bytes(8).unpack1("H*")}", packageName: app_id, productId: product_id,
                           purchaseTime: (at.to_f * 1000).to_i, purchaseState: state, quantity: 1, acknowledged: true)
      signature = OpenSSL::PKey.read(key).sign("SHA1", json)
      "play:#{[json].pack("m0")}:#{[signature].pack("m0")}"
    end

    # A test build (no channel) trusts only the fake store's receipts; a
    # build for sale, its store's (Receipt.trusted).
    module TrustOfTestBuild
      def trusted(channel) = Build.store?(channel) ? super : TEST
    end
    singleton_class.prepend(TrustOfTestBuild)
  end
end
