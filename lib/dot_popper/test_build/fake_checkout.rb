# frozen_string_literal: true

module DotPopper
  # The test build's checkout: no browser and no payment, and at once a
  # real license key, signed by the test key the test build trusts, on
  # the clipboard, where an email's copy would put it. Paste license key
  # then takes the same road a bought key does.
  class FakeCheckout < Data.define(:clipboard)
    def buy
      clipboard.copy(Continuity::LicenseKey.issue(Continuity::TestKeys::LICENSE).text)
      :copied
    end
  end
end
