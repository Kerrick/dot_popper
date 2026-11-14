# frozen_string_literal: true

module DotPopper
  module Receipt
    # Google Play: the purchase's JSON, signed by the app's Play key, for
    # this package and product, and purchased. Play's JSON gives
    # purchaseState 0 for a purchase and 4 for a pending one (inference,
    # from Play Billing's Purchase#getPurchaseState, which treats any
    # other value as purchased; only 0 is taken here).
    module Play
      module_function

      # +text+ is "<JSON>:<signature>", each in standard Base64.
      def valid?(text, trust)
        Receipt.load_openssl
        json64, signature64 = text.split(":", 2)
        json = json64.to_s.unpack1("m").to_s
        signature = signature64.to_s.unpack1("m").to_s
        return false unless trust.play_keys.any? { OpenSSL::PKey.read(it).verify("SHA1", signature, json) }

        purchase = JSON.parse(json)
        products = Array(purchase["productIds"]) + Array(purchase["productId"])
        purchase["packageName"] == trust.app_id && products.include?(trust.product_id) && purchase.fetch("purchaseState", 0).zero?
      rescue StandardError, ScriptError
        false
      end
    end
  end
end
