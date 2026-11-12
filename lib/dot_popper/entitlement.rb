# frozen_string_literal: true

module DotPopper
  # Whether this player has Pro. Pro comes only from proof the game checks
  # by itself, offline, every launch, and never from anything it stored
  # (ADR-0010): a store copy's
  # receipt, which the store hands over at each launch and #prove verifies
  # (Receipt), or a website copy's license key (+license+,
  # Continuity::License), whose signature is checked against the pinned
  # keys. Pro features ask +pro?+ and nothing else. DOT_POPPER_PRO=1
  # stands in for a purchase in a test build, to try them out, and
  # DOT_POPPER_PRO=0 is a free player; a store build never reads it
  # (Build.settings).
  class Entitlement
    FORCED_BY = "DOT_POPPER_PRO"
    # Whether a computer's copy has everything for nothing. It does not: a
    # desktop copy is free until a store, a channel's or a test build's fake,
    # sells it (Presentation::Storefront; ADR-0009). Set it true to ship a desktop copy
    # whole. The systems that have a store of their own are STORE_SYSTEMS,
    # as Lota::System.os names them.
    DESKTOP_PRO = false
    STORE_SYSTEMS = %w[iOS Android].freeze

    # An entitlement with no proof, as a store build's starts.
    def self.free = new

    # A test build's, which takes the fake store's receipts (Receipt::TEST).
    def self.test = new(trust: Receipt::TEST)

    # Whether this copy is pro without a purchase: by DOT_POPPER_PRO when
    # it is set, and otherwise on a computer (+os+ as Lota::System.os names
    # it), by DESKTOP_PRO.
    def self.forced?(env, os: nil)
      value = env.fetch(FORCED_BY, "")
      return value == "1" unless value.empty?

      DESKTOP_PRO && !os.nil? && !STORE_SYSTEMS.include?(os)
    end

    # +license+ (Continuity::License, or anything that answers pro?) is a
    # website copy's. +trust+ (Receipt::Trust) is whose receipts this build
    # accepts: the stores' in a store build, the fake store's in a test
    # build.
    def initialize(forced: false, license: nil, trust: Receipt::STORES)
      @forced = forced
      @license = license
      @trust = trust
      @proven = false
      @refused = nil
    end

    def pro? = @forced || @proven || @license&.pro? || false

    # Takes +receipt+, the text a store handed over, as proof of Pro for
    # as long as the game runs, if it verifies. Nothing is saved: the next
    # launch asks the store again. Says whether it verified. A receipt
    # already refused is not checked again, since the store's answer is
    # read a few times a second.
    def prove(receipt)
      return @proven if @proven || receipt == @refused

      @proven = Receipt.valid?(receipt, @trust)
      @refused = receipt unless @proven
      @proven
    end
  end
end
