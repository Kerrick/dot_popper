# frozen_string_literal: true

module DotPopper
  # How many games a player who has not bought Pro may still
  # start. A free game is one started game. Watching the Tutorial or "How
  # to play" costs nothing; the game either goes on into costs one. A
  # fresh install holds FIRST_GAMES games for good, which never refill,
  # and DAILY games for each local day, which do not carry over. Each game
  # spends the day's own first, so the first games last. There is no
  # way to earn more. Paying makes play unlimited (+entitlement+), and
  # +metered+ false counts nothing: for a machine playing, and for a build
  # with no store to pay in, as no one could then get past the limit. A
  # test build has a store, a fake one, so it is metered like the final
  # game.
  #
  # The store answers +read+ and +write(text)+ as ScoreRecord's does; its
  # lines are +day=2026-11-08+, +spent=2+ and +first_games_used=3+. A
  # store with nothing in it, as on every save made before games were
  # counted, has all its first games. An earlier save kept the first games
  # left instead, as +bank=17+; it is read as FIRST_GAMES less those, and
  # written the new way at the next game. A player's clock is trusted, as
  # the other saves trust it.
  class FreeGames
    # The first games, for good, and the games each day. Both are
    # provisional (ADR-0012).
    FIRST_GAMES = 20
    DAILY = 3
    # The old name, until no commit uses it.
    BANK = FIRST_GAMES

    # Whether the free games of a run with the developer settings +env+
    # (Build.settings) in a build for +channel+ are counted: where Pro can
    # be bought (+offered+), as a limit with no way past it is a dead end,
    # and someone is playing (.player?).
    def self.metered?(env, channel:, offered:) = offered && player?(env, channel:)

    # Whether someone is playing, not a machine. In a build for sale
    # everyone is, whatever its settings say (ADR-0010); a test build tells
    # its bot and scenarios apart (lib/dot_popper/test_build).
    def self.player?(_env, channel:) = true

    # The games a developer setting asks a new save to start with, or nil:
    # never in a build for sale.
    def self.starting(_env) = nil

    # Games that never count and never show: for a Show made without any.
    def self.unlimited = new(ScoreRecord::Memory.new, today: -> { Date.today }, entitlement: Entitlement.free, metered: false)

    # +today+ answers the player's local Date; +first_games+ and +daily+ are
    # what a new save starts with and each day gives. +bank+ is
    # +first_games+'s old name, until no commit uses it.
    def initialize(store, today:, entitlement:, metered: true, bank: nil, first_games: bank || FIRST_GAMES, daily: DAILY)
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
      @first_games = first_games
      @used = count(values["first_games_used"], first_games - [count(values["bank"], first_games), first_games].min)
    end

    # Whether games are counted and shown: where Pro can be
    # bought, and has not been.
    def metered? = @metered && !@entitlement.pro?

    # The games left today, the first games left, and both together.
    def daily_left = @day == today ? [@daily - @spent, 0].max : @daily
    def first_games_left = [@first_games - @used, 0].max
    def left = daily_left + first_games_left

    # The old name, until no commit uses it.
    def bank_left = first_games_left

    # How many free games come each day.
    attr_reader :daily

    def can_play? = !metered? || left.positive?

    # Spends the game that starting one would use, and says whether there
    # was one. Pro or unmetered, it counts nothing and always is.
    def spend!
      return true unless metered?
      return false unless left.positive?

      if daily_left.positive?
        @spent = (@day == today ? @spent : 0) + 1
        @day = today
      else
        @used += 1
      end
      @store.write("day=#{@day&.iso8601}\nspent=#{@spent}\nfirst_games_used=#{@used}\n")
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
