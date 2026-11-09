# frozen_string_literal: true

module DotPopper
  # Whether this player has bought Pro. The store, which
  # answers +read+ and +write(text)+ as ScoreRecord's does, keeps it. Pro
  # features ask +pro?+ and nothing else, so the store's purchase is one
  # call, +unlock!+, away from every one of them. DOT_POPPER_PRO=1 stands
  # in for a purchase, to try them out, and DOT_POPPER_PRO=0 is a free
  # player even on a computer.
  class Entitlement
    PRO = "pro"
    FORCED_BY = "DOT_POPPER_PRO"
    # Whether a computer's copy has everything for nothing. It does not: a
    # desktop copy is free until a store, a channel's or a test build's fake,
    # sells it (Presentation::Storefront; doc/decisions.md, "Desktop is
    # free until a channel sells it" and "The store is a port"). Set it true to ship a desktop copy
    # whole. The systems that have a store of their own are STORE_SYSTEMS,
    # as Lota::System.os names them.
    DESKTOP_PRO = false
    STORE_SYSTEMS = %w[iOS Android].freeze

    # An entitlement that has bought nothing and keeps nothing.
    def self.free = new(ScoreRecord::Memory.new)

    # Whether this copy is pro without a purchase: by DOT_POPPER_PRO when
    # it is set, and otherwise on a computer (+os+ as Lota::System.os names
    # it), by DESKTOP_PRO.
    def self.forced?(env, os: nil)
      value = env.fetch(FORCED_BY, "")
      return value == "1" unless value.empty?

      DESKTOP_PRO && !os.nil? && !STORE_SYSTEMS.include?(os)
    end

    def initialize(store, forced: false)
      @store = store
      @forced = forced
    end

    def pro? = @forced || @store.read.to_s.strip == PRO

    def unlock! = @store.write(PRO)
  end
end
