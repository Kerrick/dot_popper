# frozen_string_literal: true

module DotPopper
  # Whether this player has Pro. Pro comes only from proof the game checks
  # by itself, offline, every launch, and never from anything it stored
  # (ADR-0010): a store copy's
  # receipt, which the store hands over at each launch and #prove verifies
  # (Receipt), or a website copy's license key (+license+,
  # Continuity::License), whose signature is checked against the pinned
  # keys. Pro features ask +pro?+ and nothing else. A test build has a
  # developer setting of its own that stands in for a purchase
  # (lib/dot_popper/test_build).
  #
  # Pro arriving during a run, by a receipt that verifies or a license key
  # entered through #enter, is announced to every listener (#subscribe)
  # as a ProGranted, once. Pro the game starts with, from a key already
  # entered or forced (.forced?), is not an arrival.
  class Entitlement
    # Pro arrived +by+ a store's receipt (:receipt) or a license key
    # (:license_key).
    class ProGranted < Data.define(:by); end

    # Whether a computer's copy has everything for nothing. It does not: a
    # desktop copy is free until a store, a channel's or a test build's fake,
    # sells it (Store; ADR-0009). Set it true to ship a desktop copy
    # whole. A phone's copy is never pro this way: its host has a store of
    # its own (Platform#phone_host?).
    DESKTOP_PRO = false

    # An entitlement with no proof, as a store build's starts.
    def self.free = new

    # Whether this copy is pro without a purchase: on a computer
    # (+platform+, a Platform), by DESKTOP_PRO. +env+ is the developer
    # settings this build obeys (Build.settings), which a build for sale
    # never lets decide it.
    def self.forced?(_env, platform: nil) = DESKTOP_PRO && !platform.nil? && !platform.phone_host?

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
      @listeners = []
    end

    # Adds a listener: anything that answers +call(event)+.
    def subscribe(listener)
      @listeners << listener
      self
    end

    def pro? = @forced || @proven || @license&.pro? || false

    # Takes +receipt+, the text a store handed over, as proof of Pro for
    # as long as the game runs, if it verifies. Nothing is saved: the next
    # launch asks the store again. Says whether it verified. A receipt
    # already refused is not checked again, since the store's answer is
    # read a few times a second.
    def prove(receipt)
      return @proven if @proven || receipt == @refused

      before = pro?
      @proven = Receipt.valid?(receipt, @trust)
      @refused = receipt unless @proven
      granted(:receipt) if @proven && !before
      @proven
    end

    # Enters +text+ as a website copy's license key (Continuity::License#enter),
    # and answers what that answered: :entered (Pro from now on), :same, or
    # :invalid, as with no license to enter it in.
    def enter(text)
      license = @license or return :invalid

      before = pro?
      result = license.enter(text)
      granted(:license_key) if pro? && !before
      result
    end

    private

    def granted(by)
      event = ProGranted.new(by:)
      @listeners.each { it.call(event) }
    end
  end
end
