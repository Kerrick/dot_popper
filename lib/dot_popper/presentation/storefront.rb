# frozen_string_literal: true

module DotPopper
  module Presentation
    # The store behind the paid version, on the systems that have one.
    # Neither Lota nor LÖVE knows a store, so this works as SheetSharing
    # does: the game opens a URL in its own SCHEME, and the app's host
    # catches it before it leaves the app and asks StoreKit or Play Billing
    # (doc/decisions.md). The store's answer comes back in a small file the
    # host rewrites whole, named in the URL (+answers+), which #update
    # reads a few times a second, outside a round. Each answer is the
    # whole state, so one that is missed costs nothing: whether the player
    # owns the product, its price as the store writes it, how the last
    # request went, and that request's number.
    #
    # +opener+ answers open(url) with whether it was taken; +answers+
    # answers read, remove and path; +entitlement+ (Entitlement) is
    # unlocked the moment the store says the product is owned. A store that
    # later says otherwise, as after a refund, locks nothing
    # (doc/decisions.md).
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
      # The channel this build is sold through, or nil for none. A build
      # for a channel sets it; DOT_POPPER_CHANNEL does the same for a try.
      BUILD_CHANNEL = nil
      CHANNEL_SETTING = "DOT_POPPER_CHANNEL"

      # The channel this build is sold through, as +env+ and the build say.
      def self.channel(env)
        named = env.fetch(CHANNEL_SETTING, "")
        named.empty? ? BUILD_CHANNEL : named
      end

      # The storefront for +os+: the store where the host has one; else, on
      # a computer, its channel's store; else none, which offers nothing, so
      # no one is offered a purchase that cannot complete. A channel nobody
      # has built is none.
      def self.for(os, opener:, answers:, entitlement:, channel: nil, channels: CHANNELS)
        return new(opener:, answers:, entitlement:) if SYSTEMS.include?(os)

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

      def initialize(opener:, answers:, entitlement:)
        @opener = opener
        @answers = answers
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

        @answers.remove
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
        heard(@answers.read)
      end

      private

      def request(action, status)
        @number += 1
        @status = @opener.open(self.class.url(action, @number, @answers.path)) ? status : :unavailable
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

    # A store that answers at once and from nowhere, to rehearse the offer
    # without one (DOT_POPPER_FAKE_STORE=1): it writes what the host would
    # write, and buying always succeeds.
    class RehearsalStore
      attr_reader :text
      alias read text

      def initialize = @text = nil
      def path = "rehearsal"
      def remove = @text = nil

      def open(url)
        number = url[/n=(\d+)/, 1]
        @text = "answer=#{number}\nowned=#{url.include?('://buy') ? 1 : 0}\nstate=ready\nprice=$1.99\n"
        true
      end
    end

    # Where there is no store, as on a computer whose build has no channel:
    # nothing is offered.
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
