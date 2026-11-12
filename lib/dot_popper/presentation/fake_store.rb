# frozen_string_literal: true

module DotPopper
  module Presentation
    # A store that is not a store, behind the same port as the real ones
    # (Storefront; test/presentation/store_contract.rb), for a build with
    # no channel: what playtesters run. It answers +open+, +read+, +remove+
    # and +path+ as the app's host does, and writes the host's own answers
    # (Host/Store.swift, ProStore.java): the whole state each time, a
    # "loading" or "working" answer first and the real one a few reads
    # later, as a store takes a moment. Everything above it, the offer and
    # the price and the thanks, is the code a store build runs.
    #
    # The +ledger+ (read and write(text), as ScoreRecord's store) is the
    # store's own record of what this install bought, apart from the
    # game's Entitlement, as Apple's and Google's caches are; so Restore
    # finds a purchase, and a launch sees one, the way a real store would.
    # What it keeps is the receipt itself, in Play's form, signed by the
    # test key (Receipt.issue), and every answer that owns Pro hands it
    # over, so the game proves a fake purchase by the code that proves a
    # real one. Only a test build trusts that key (Receipt::TEST); a ledger
    # edited to say anything else is a receipt that does not verify.
    #
    # +fails+ takes the part of the store going wrong, for a developer
    # (FAILS_BY) and never on any screen: "refused", the system would not
    # take the request; "unavailable", no store answers; and "failed",
    # "canceled" and "pending", what a Buy or a Restore can come back as
    # ("pending" is a Buy's alone; a Restore goes on as usual).
    class FakeStore
      FAILS_BY = "DOT_POPPER_FAKE_STORE_FAILS"
      FAILURES = %w[refused unavailable failed canceled pending].freeze
      PRICE = "$1.99"
      # How many reads of the answer, a quarter second apart, a request
      # takes to come back.
      READS = 2
      # What a pretend purchase was signed for before Pro's product id was
      # lowercased.
      EARLIER = Receipt::TEST.with(product_id: "com.setdef.DotPopper.pro")

      # The failure +env+ asks for, or nil.
      def self.failure(env) = env.fetch(FAILS_BY, "").then { it if FAILURES.include?(it) }

      def initialize(ledger, fails: nil, reads: READS)
        @ledger = ledger
        @fails = fails
        @reads = reads
        @text = nil
        @asked = nil
        @waiting = 0
        @price = ""
      end

      def path = "fake-store-answer"

      def open(url)
        return false if @fails == "refused"

        @asked = [url[%r{://(\w+)}, 1], url[/[?&]n=(\d+)/, 1].to_i]
        @waiting = @reads
        write(@asked.first == "open" ? "loading" : "working")
        true
      end

      def read
        settle
        @text
      end

      def remove = @text = nil

      private

      # The answer to the request in hand, once it has waited long enough.
      def settle
        return unless @asked

        @waiting -= 1
        return if @waiting.positive?

        action, = @asked
        write(outcome(action))
        @asked = nil
      end

      def outcome(action)
        return "unavailable" if @fails == "unavailable"

        case action
        when "open" then opened
        when "buy" then bought
        when "restore" then restored
        else "failed"
        end
      end

      def opened
        @price = PRICE
        "ready"
      end

      def bought
        return "failed" if @price.empty?
        return @fails if %w[failed canceled pending].include?(@fails)

        @ledger.write(Receipt.issue)
        "ready"
      end

      def restored
        return @fails if %w[failed canceled].include?(@fails)

        owned? ? "restored" : "none"
      end

      # What the ledger holds. A pretend purchase made under Pro's earlier
      # product id is bought again under today's, as a store would carry
      # its own purchase over, so a playtester keeps pretend Pro.
      def receipt
        text = @ledger.read.to_s.strip
        return text unless Receipt.valid?(text, EARLIER)

        Receipt.issue.tap { @ledger.write(it) }
      end

      def owned? = !receipt.empty?

      def write(state)
        @text = "answer=#{@asked.last}\nowned=#{owned? ? 1 : 0}\nstate=#{state}\nprice=#{@price}\n"
        @text += "receipt=#{receipt}\n" if owned?
      end
    end
  end
end
