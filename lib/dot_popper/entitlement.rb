# frozen_string_literal: true

module DotPopper
  # Whether this player has bought the paid version. The store, which
  # answers +read+ and +write(text)+ as BestScore's does, keeps it. Paid
  # features ask +paid?+ and nothing else, so the store's purchase is one
  # call, +unlock!+, away from every one of them. DOT_POPPER_PAID=1 stands
  # in for a purchase, to try them out.
  class Entitlement
    PAID = "paid"
    FORCED_BY = "DOT_POPPER_PAID"

    # An entitlement that has bought nothing and keeps nothing.
    def self.free = new(BestScore::Memory.new)

    def self.forced?(env) = env.fetch(FORCED_BY, "") == "1"

    def initialize(store, forced: false)
      @store = store
      @forced = forced
    end

    def paid? = @forced || @store.read.to_s.strip == PAID

    def unlock! = @store.write(PAID)
  end
end
