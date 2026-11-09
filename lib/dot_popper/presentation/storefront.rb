# frozen_string_literal: true

module DotPopper
  module Presentation
    # The store behind the paid version. Neither Lota nor LÖVE knows a
    # store, so this works as SheetSharing does: the game opens a URL in
    # its own SCHEME, and the store's answer comes back in a small file,
    # named in the URL, rewritten whole, which #update reads a few times a
    # second, outside a game. Each answer is the whole state, so one that
    # is missed costs nothing: whether the player owns the product, its
    # price as the store writes it, how the last request went, and that
    # request's number.
    #
    # That URL and that file are the port: +port+ answers open(url) with
    # whether it was taken, and read, remove and path for the answer.
    # NativeStore is the adapter for the app's host, which catches the URL
    # before it leaves the app and asks StoreKit or Play Billing; FakeStore
    # is the adapter for a build with no channel, a test build. Which one
    # is chosen once, by Storefront.for, at the composition root
    # (Shell::App), from the build; nothing above the port differs between
    # them (test/presentation/store_contract.rb, doc/decisions.md).
    # +entitlement+ (Entitlement) is unlocked the moment the store says the
    # product is owned. A store that later says otherwise, as after a
    # refund, locks nothing (doc/decisions.md).
    class Storefront
      SCHEME = "dotpopper-store"
      # The one product, as App Store Connect and the Play Console must
      # name it (and ios/store_check's StoreKit configuration file).
      PRODUCT_ID = "com.setdef.DotPopper.paid"
      # The systems whose hosts catch SCHEME, as Lota::System.os names them.
      SYSTEMS = %w[iOS Android].freeze
      # How often, in seconds, the answer file is read.
      EVERY = 0.25
      # What a query value keeps as it is, as in SheetSharing.
      UNRESERVED = /[^A-Za-z0-9\-._~]/n
      # The hosts' states that a screen tells apart; any other is :failed.
      STATES = { "loading" => :loading, "working" => :busy, "ready" => :ready, "pending" => :pending,
                 "cancelled" => :ready, "restored" => :ready, "none" => :none, "failed" => :failed,
                 "unavailable" => :unavailable }.freeze

      attr_reader :status, :price

      # The distribution channels that can sell the paid version on a
      # computer, by name, each a callable that takes +entitlement:+ and
      # answers a store like this class (offered?, status, price, connect,
      # buy, restore, update). None is built yet, so every desktop build is
      # free. To add one: write its store, register it here under its name,
      # and set BUILD_CHANNEL for the build that ships through it. Nothing
      # that is paid for needs to change, since features ask only
      # Entitlement#paid?.
      CHANNELS = {}.freeze
      # The channel this build is sold through, or nil for a test build.
      # A build for a store MUST set it, or it ships with the fake store
      # (doc/decisions.md, "The store is a port").
      BUILD_CHANNEL = nil

      # Whether this is a build for playtesters rather than a store: one
      # with no channel, as every CI kit is today.
      def self.test_build? = BUILD_CHANNEL.nil?

      # The storefront for this build, chosen once: with no +channel+, a
      # test build, the +fake+ port on every system. With one, the +native+
      # port where the host has a store, and else, on a computer, the
      # channel's own store, or none, which offers nothing, so no one is
      # offered a purchase that cannot complete. A channel nobody has built
      # is none.
      def self.for(os, native:, fake:, entitlement:, channel: BUILD_CHANNEL, channels: CHANNELS)
        return new(port: fake, entitlement:) if channel.nil?
        return new(port: native, entitlement:) if SYSTEMS.include?(os)

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

      # Asks the store for the price and what this player owns: at launch,
      # so a purchase on another device or after a reinstall simply
      # appears, and each time the offer opens, which also clears a request
      # the store never answered. An old answer is thrown away first.
      def connect
        return if @entitlement.paid?

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
        @entitlement.unlock! if answer["owned"] == "1" && !@entitlement.paid?
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
      def status = :unavailable
      def price = nil
      def connect = nil
      def buy = nil
      def restore = nil
      def update(_seconds) = nil
    end
  end
end
