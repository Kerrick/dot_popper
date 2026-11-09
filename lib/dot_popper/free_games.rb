# frozen_string_literal: true

module DotPopper
  # How many games a player who has not bought the paid version may still
  # start. A free game is one started game; the Tutorial and "How to play"
  # never cost one. A fresh install holds BANK games for good, which never
  # refill, and DAILY games for each local day, which do not carry over.
  # Each game spends the day's own first, so the bank lasts. There is no
  # way to earn more. Paying makes play unlimited (+entitlement+), and
  # +metered+ false counts nothing: for a machine playing, and for a build
  # with no store to pay in, as no one could then get past the limit. A
  # test build has a store, a fake one, so it is metered like the final
  # game.
  #
  # The store answers +read+ and +write(text)+ as ScoreRecord's does; its
  # lines are +day=2026-11-08+, +spent=2+ and +bank=17+. A store with
  # nothing in it, as on every save made before games were counted, is a
  # full bank. A player's clock is trusted, as the other saves trust it.
  class FreeGames
    # The one-time bank, and the games each day. Both are provisional
    # (doc/decisions.md, "Free games").
    BANK = 20
    DAILY = 3

    # Games that never count and never show: for a Show made without any.
    def self.unlimited = new(ScoreRecord::Memory.new, today: -> { Date.today }, entitlement: Entitlement.free, metered: false)

    # +today+ answers the player's local Date; +bank+ and +daily+ are what a
    # new save starts with and each day gives.
    def initialize(store, today:, entitlement:, metered: true, bank: BANK, daily: DAILY)
      @store = store
      @today = today
      @entitlement = entitlement
      @metered = metered
      @daily = daily
      values = {} #: Hash[String, String]
      store.read.to_s.each_line do |line|
        name, value = line.strip.split("=", 2)
        values[name] = value if name && value
      end
      @day = day(values["day"])
      @spent = count(values["spent"], 0)
      @bank = count(values["bank"], bank)
    end

    # Whether games are counted and shown: where the paid version can be
    # bought, and has not been.
    def metered? = @metered && !@entitlement.paid?

    # The games left today, those the bank holds, and both together.
    def daily_left = @day == today ? [@daily - @spent, 0].max : @daily
    def bank_left = @bank
    def left = daily_left + bank_left

    # How many free games come each day.
    attr_reader :daily

    def can_play? = !metered? || left.positive?

    # Spends the game that starting one would use, and says whether there
    # was one. Paid or unmetered, it counts nothing and always is.
    def spend!
      return true unless metered?
      return false unless left.positive?

      if daily_left.positive?
        @spent = (@day == today ? @spent : 0) + 1
        @day = today
      else
        @bank -= 1
      end
      @store.write("day=#{@day&.iso8601}\nspent=#{@spent}\nbank=#{@bank}\n")
      true
    end

    private

    def today = @today.call

    # The date in +text+, or nil.
    def day(text)
      Date.iso8601(text.to_s)
    rescue ArgumentError
      nil
    end

    # A whole number, no less than 0, or +default+.
    def count(text, default)
      number = Integer(text.to_s, 10, exception: false)
      number && !number.negative? ? number : default
    end
  end
end
