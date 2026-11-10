# frozen_string_literal: true

module DotPopper
  module Receipt
    # The App Store: StoreKit 2's signed transaction, a JWS whose x5c chain
    # runs from a leaf Apple marks for signing receipts
    # (1.2.840.113635.100.6.11.1), through an intermediate it marks as its
    # WWDR CA (1.2.840.113635.100.6.2.1), to a pinned root; its ES256
    # signature by the leaf; and for this app and product, not revoked.
    # The chain is judged at the transaction's own signedDate, since a
    # device's clock proves nothing either way, and with no revocation
    # check, which would need the network. These are the checks Apple's
    # App Store Server Library makes, less the online ones.
    module Apple
      LEAF = "1.2.840.113635.100.6.11.1"
      INTERMEDIATE = "1.2.840.113635.100.6.2.1"

      module_function

      def valid?(jws, trust)
        return false if trust.apple_roots.empty?

        Receipt.load_openssl
        head64, body64, signature64 = jws.split(".")
        header = JSON.parse(decode(head64))
        return false unless header["alg"] == "ES256"

        leaf, intermediate, = Array(header["x5c"]).map { OpenSSL::X509::Certificate.new(it.to_s.unpack1("m").to_s) }
        return false unless leaf && intermediate && marked?(leaf, LEAF) && marked?(intermediate, INTERMEDIATE)

        transaction = JSON.parse(decode(body64))
        return false unless chained?(leaf, intermediate, trust, Time.at(Integer(transaction.fetch("signedDate")) / 1000r))
        return false unless leaf.public_key.verify("SHA256", der(decode(signature64)), "#{head64}.#{body64}")

        transaction["bundleId"] == trust.app_id && transaction["productId"] == trust.product_id && transaction["revocationDate"].nil?
      rescue StandardError, ScriptError
        false
      end

      def chained?(leaf, intermediate, trust, at)
        store = OpenSSL::X509::Store.new
        trust.apple_roots.each { store.add_cert(OpenSSL::X509::Certificate.new(it)) }
        store.time = at
        store.verify(leaf, [intermediate])
      end

      def marked?(certificate, oid) = certificate.extensions.any? { it.oid == oid }

      def decode(text) = text.to_s.tr("-_", "+/").then { it + ("=" * (-it.size % 4)) }.unpack1("m").to_s

      # A JWS's raw r and s, as the DER that OpenSSL verifies.
      def der(raw)
        return "" unless raw.bytesize == 64

        OpenSSL::ASN1::Sequence.new([raw[0, 32], raw[32, 32]].map { OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(it.to_s, 2)) }).to_der
      end
    end
  end
end
