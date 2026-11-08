# frozen_string_literal: true

module DotPopper
  # Whether this player has bought the paid version. The store, which
  # answers +read+ and +write(text)+ as BestScore's does, keeps it. Paid
  # features ask +paid?+ and nothing else, so the store's purchase is one
  # call, +unlock!+, away from every one of them. DOT_POPPER_PAID=1 stands
  # in for a purchase, to try them out, and DOT_POPPER_PAID=0 is a free
  # player even on a computer.
  class Entitlement
    PAID = "paid"
    FORCED_BY = "DOT_POPPER_PAID"
    # Whether a computer's copy has everything: no store sells inside it, so
    # a desktop copy is sold (or given) already whole. The one setting;
    # doc/decisions.md, "Buying the paid version". The systems that do have
    # a store are STORE_SYSTEMS, as Lota::System.os names them.
    DESKTOP_PAID = true
    STORE_SYSTEMS = %w[iOS Android].freeze

    # An entitlement that has bought nothing and keeps nothing.
    def self.free = new(BestScore::Memory.new)

    # Whether this copy is paid without a purchase: by DOT_POPPER_PAID when
    # it is set, and otherwise on a computer (+os+ as Lota::System.os names
    # it), by DESKTOP_PAID.
    def self.forced?(env, os: nil)
      value = env.fetch(FORCED_BY, "")
      return value == "1" unless value.empty?

      DESKTOP_PAID && !os.nil? && !STORE_SYSTEMS.include?(os)
    end

    def initialize(store, forced: false)
      @store = store
      @forced = forced
    end

    def paid? = @forced || @store.read.to_s.strip == PAID

    def unlock! = @store.write(PAID)
  end
end
