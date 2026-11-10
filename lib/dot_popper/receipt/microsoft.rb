# frozen_string_literal: true

module DotPopper
  module Receipt
    # The Microsoft Store: not a signature but Windows' own word. Its
    # purchase API, Windows.Services.Store, gives an app no receipt for an
    # add-on, only the licenses the user holds (StoreAppLicense's
    # AddOnLicenses), which Windows keeps and answers from. So the game
    # cannot check this one itself: it can only take Windows' answer, and
    # only by a road no text file is on (doc/decisions.md, "The Mac App
    # Store and the Microsoft Store sell Pro"). The text is
    # "<in-app offer token>:<SKU Store ID>", as the Microsoft Store build's
    # helper (windows/store) writes it down its pipe.
    #
    # It proves Pro only under a Trust that takes Windows' word
    # (+windows_license+), which only the Microsoft Store build holds, and
    # whose store's answers come only through that pipe
    # (Shell::StoreHelper). Every other build refuses it, so writing it
    # into a store answer file does nothing.
    module Microsoft
      # A SKU's Store ID: the product's twelve characters, a slash, and
      # the SKU's four.
      SKU = %r{\A[0-9A-Z]{12}/[0-9A-Z]{4}\z}

      module_function

      def valid?(text, trust)
        return false unless trust.windows_license

        token, sku = text.split(":", 2)
        token == trust.product_id && SKU.match?(sku.to_s)
      end
    end
  end
end
