# frozen_string_literal: true

module DotPopper
  # This device's LifetimeStats, kept in a store that answers +read+ and
  # +write(text)+, as BestScore's is. +today+ gives the player's local
  # date. A store that is missing or damaged starts from nothing, or from
  # what it could read. A store written before bests were kept by class
  # gives its bests to +legacy+ and is saved again at once, as BestScore
  # does.
  class Lifetime
    attr_reader :stats

    def initialize(store, today: -> { Date.today }, legacy: SizeClass::MEDIUM)
      @store = store
      @today = today
      @legacy = legacy
      text = store.read
      @stats = LifetimeStats.parse(text, legacy:)
      store.write(stats.to_text) if LifetimeStats.old?(text)
    end

    # Adds a finished game's RoundStats, played on a screen of
    # +size_class+, saves, and says what the game did: the records it set
    # among that class's bests, most impressive first, and whether it was
    # the first to meet today's goal.
    def record(game, size_class)
      day = today
      records = stats.records_set_by(game, size_class)
      goal_met = !stats.streak.done_on?(day) && DailyGoal.for(day).met?(game)
      @stats = stats.add(game, day: day.iso8601, size_class:)
      @stats = stats.with(streak: stats.streak.meet(day)) if goal_met
      @store.write(stats.to_text)
      Result.new(records:, goal_met:)
    end

    def today = @today.call

    # The store's whole text, as saved, for #restore (RecordKeeper).
    def saved = @store.read

    # Forgets every game, as on a new device: the totals, the chart, each
    # class's bests, and the daily goal's streaks and today's goal met.
    def clear
      @stats = LifetimeStats.new
      @store.write("")
    end

    # Puts back +text+, the store's whole text as #saved gave it.
    def restore(text)
      @store.write(text.to_s)
      @stats = LifetimeStats.parse(text, legacy: @legacy)
    end

    # Today's goal, and whether a game has met it yet today.
    def goal = DailyGoal.for(today)
    def goal_done? = stats.streak.done_on?(today)

    # The days in a row, up to today, that the goal was met.
    def streak = stats.streak.current_on(today)

    # What one game did to the lifetime: +records+ (LifetimeStats::Record,
    # most impressive first) and +goal_met+.
    class Result < Data.define(:records, :goal_met); end
  end
end
