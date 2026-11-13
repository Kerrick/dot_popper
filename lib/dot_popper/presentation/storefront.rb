# frozen_string_literal: true

module DotPopper
  module Presentation
    # The store behind Pro. Neither Lota nor LÖVE knows a
    # store, so this works as SheetSharing does: the game opens a URL in
    # its own SCHEME, and the store's answer comes back in a small file,
    # named in the URL, rewritten whole, which #update reads a few times a
    # second, outside a game. Each answer is the whole state, so one that
    # is missed costs nothing: whether the player owns the product, the
    # store's signed receipt for it if so, its price as the store writes
    # it, how the last request went, and that request's number.
    #
    # That URL and that file are the port: +port+ answers open(url) with
    # whether it was taken, and read, remove and path for the answer.
    # NativeStore is the adapter for the app's host, which catches the URL
    # before it leaves the app and asks StoreKit or Play Billing; FakeStore
    # is the adapter for a build with no channel, a test build. Which one
    # is chosen once, by Storefront.for, at the composition root
    # (Shell::App), from the build; nothing above the port differs between
    # them (test/presentation/store_contract.rb, ADR-0009).
    # +entitlement+ (Entitlement) is Pro the moment the store hands over a
    # receipt that verifies (Receipt); an answer's "owned" alone proves
    # nothing. Nothing is kept: each launch asks the store again, which
    # answers from its own cache, offline too. A store that later says
    # otherwise in the same run, as after a refund, locks nothing
    # (ADR-0010).
    class Storefront
      SCHEME = "dotpopper-store"
      # The one product, as App Store Connect and the Play Console must
      # name it (and ios/store_check's StoreKit configuration file).
      PRODUCT_ID = "com.setdef.dotpopper.pro"
      # How often, in seconds, the answer file is read.
      EVERY = 0.25
      # What a query value keeps as it is, as in SheetSharing.
      UNRESERVED = /[^A-Za-z0-9\-._~]/n
      # The hosts' states that a screen tells apart; any other is :failed.
      STATES = { "loading" => :loading, "working" => :busy, "ready" => :ready, "pending" => :pending,
                 "canceled" => :ready, "restored" => :ready, "none" => :none, "failed" => :failed,
                 "unavailable" => :unavailable }.freeze

      attr_reader :status, :price

      # The distribution channels that can sell Pro on a
      # computer, by name, each a callable that takes +entitlement:+ and
      # answers a store like this class (offered?, status, price, connect,
      # buy, restore, update). None is built yet, so every desktop build is
      # free. To add one: write its store, register it here under its name,
      # and set BUILD_CHANNEL for the build that ships through it. Nothing
      # that is pro for needs to change, since features ask only
      # Entitlement#pro?.
      CHANNELS = {}.freeze
      # The channel this build is sold through, or nil for a test build.
      # A build for a store MUST set it, or it ships with the fake store
      # (ADR-0009).
      BUILD_CHANNEL = Build::CHANNEL

      # Whether this is a build for playtesters rather than a store: one
      # with no channel, as every CI kit is today.
      def self.test_build? = BUILD_CHANNEL.nil?

      # The channels of the computers' own stores, each sold for the one
      # system whose own store it is (Platform#own_store). Their copies also
      # buy through the native port. Its host is a small program shipped beside
      # the game (Shell::StoreHelper), since neither Lota nor LÖVE can call
      # StoreKit or Windows.Services.Store: the Mac App Store's uses StoreKit
      # 2 (macos/store), the Microsoft Store's Windows.Services.Store
      # (windows/store). On any other system those channels offer nothing.
      MAC_APP_STORE = Build::MAC_APP_STORE
      MICROSOFT_STORE = Build::MICROSOFT_STORE
      HELPER_CHANNELS = [MAC_APP_STORE, MICROSOFT_STORE].freeze

      # The channel for copies no store controls: setdef's website, whose
      # store is a WebsiteStore (license keys). An iOS build never takes it
      # (Apple 3.1.1); an Android build for an APK or another store does.
      WEBSITE = Build::WEBSITE

      # The storefront for this build on +platform+ (Platform), chosen once:
      # with no +channel+, a test build, on a phone the +fake+ store port, and on a computer the
      # +website+ store with its fake checkout, as computers' copies will
      # mostly be sold. With a channel, the +native+ port where the host
      # has a store or the channel is that computer's own store's
      # (Platform#own_store), the website store for WEBSITE where the
      # platform allows website sales, and else, on a
      # computer, the channel's own store, or none, which offers nothing, so
      # no one is offered a purchase that cannot complete. A channel nobody
      # has built is none. +website+ is called for the website store, with
      # whether the checkout is the test build's (+fake:+).
      def self.for(platform, native:, fake:, entitlement:, website: nil, channel: BUILD_CHANNEL, channels: CHANNELS)
        if channel.nil?
          return new(port: fake, entitlement:) if platform.phone_host? || website.nil?

          return website.call(fake: true)
        end
        return website.call(fake: false) if channel == WEBSITE && platform.website_sales? && website
        return new(port: native, entitlement:) if platform.phone_host? || platform.own_store == channel
        return NoStorefront.new if HELPER_CHANNELS.include?(channel)

        sold = channels[channel]
        sold ? sold.call(entitlement:) : NoStorefront.new
      end

      # The URL asking the host to do +action+ (:open, :buy, :restore) as
      # request number +number+, answering in the file at +path+.
      def self.url(action, number, path)
        query = { n: number, product: PRODUCT_ID, file: path }.map { |key, value| "#{key}=#{encode(value)}" }.join("&")
        "#{SCHEME}://#{action}?#{query}"
      end

      def self.encode(value) = value.to_s.b.gsub(UNRESERVED) { format("%%%02X", it.ord) }

      def initialize(port:, entitlement:)
        @port = port
        @entitlement = entitlement
        @status = :loading
        @price = nil
        @number = 0
        @since = 0.0
      end

      def offered? = true
      # A store's purchase is restored, never pasted as a key (Apple 3.1.1),
      # and it sells for as long as the store lists it.
      def keys? = false
      def sold? = true
      def paste = nil
      def type(_key) = false

      # Asks the store for the price and what this player owns: at launch,
      # so a purchase on another device or after a reinstall simply
      # appears, and each time the offer opens, which also clears a request
      # the store never answered. An old answer is thrown away first.
      def connect
        return if @entitlement.pro?

        @port.remove
        request(:open, :loading)
      end

      def buy
        request(:buy, :busy) if price && @status != :busy
      end

      def restore
        request(:restore, :busy) unless @status == :busy
      end

      # Reads the store's answer, EVERY so often, as the frames pass.
      def update(seconds)
        @since += seconds
        return if @since < EVERY

        @since = 0.0
        heard(@port.read)
      end

      private

      def request(action, status)
        @number += 1
        @status = @port.open(self.class.url(action, @number, @port.path)) ? status : :unavailable
      end

      def heard(text)
        return unless text

        answer = text.lines.to_h { it.chomp.split("=", 2) }
        @entitlement.prove(answer["receipt"]) if answer["receipt"] && !@entitlement.pro?
        return unless answer["answer"].to_i >= @number

        @price = answer["price"] unless answer["price"].to_s.empty?
        @status = STATES.fetch(answer["state"], :failed)
      end
    end

    # The adapter for the app's host: its URLs go out by +opener+ and its
    # answers come back in +answers+, a file the host rewrites.
    class NativeStore < Data.define(:opener, :answers)
      def open(url) = opener.open(url)
      def read = answers.read
      def remove = answers.remove
      def path = answers.path
    end

    # Where there is no store, as on a computer whose build names a channel
    # nobody has built: nothing is offered.
    class NoStorefront
      def offered? = false
      def keys? = false
      def sold? = false
      def paste = nil
      def type(_key) = false
      def status = :unavailable
      def price = nil
      def connect = nil
      def buy = nil
      def restore = nil
      def update(_seconds) = nil
    end
  end
end
