# frozen_string_literal: true

module DotPopper
  module Presentation
    # The store for copies no store controls: those from setdef's website,
    # itch.io, Homebrew, winget, a Linux package or an APK. Buy opens a
    # checkout in a web browser, which sells a license key by email, and
    # Paste license key enters it (Continuity::License), so it answers the
    # Storefront's methods and two of its own: #keys?, that a key is how
    # Pro arrives here, and #paste. It has no Restore: the key is the
    # purchase, and it works on any device. While setdef is gone (+gone+,
    # Continuity::Gone) Pro is no longer sold: Buy goes, and the offer says
    # so, but a key bought earlier still enters.
    #
    # +checkout+ is the port to the seller: #buy answers the state to show
    # (:browser once a browser took the checkout, :copied for the test
    # build's fake, which puts a real signed test key on the clipboard, or
    # :unavailable). BrowserCheckout is the real adapter; FakeCheckout the
    # test build's. A payment company has not been chosen, and none needs
    # to be for either.
    class WebsiteStore
      # The price as the checkout page sets it. Change both together.
      PRICE = "$1.99"

      attr_reader :status

      def initialize(checkout:, license:, gone:, clipboard:, entered: -> {})
        @checkout = checkout
        @license = license
        @gone = gone
        @clipboard = clipboard
        @entered = entered
        @status = :ready
      end

      def offered? = true
      def keys? = true
      def sold? = !@gone.gone?
      def price = (PRICE if sold?)

      # The offer opened: a fresh start, or the word that Pro is no longer sold.
      def connect = @status = sold? ? :ready : :not_sold

      def buy
        @status = @checkout.buy if sold?
      end

      def restore = nil
      def update(_seconds) = nil

      # Enters what is on the clipboard as a license key: :entered (Pro
      # from now on), :same, :invalid, or :empty with nothing to paste.
      def paste
        text = @clipboard.paste.to_s
        result = text.strip.empty? ? :empty : @license.enter(text)
        @entered.call if result == :entered
        @status = result
      end
    end

    # The checkout on setdef's website, opened in the player's browser by
    # +opener+ (Shell::UrlOpener). Its address is the one constant to set
    # once a payment company is chosen.
    class BrowserCheckout < Data.define(:opener)
      URL = "https://dot-popper.setdef.com/buy"

      def buy = opener.open(URL) ? :browser : :unavailable
    end

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
end
