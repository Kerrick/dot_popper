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
      text = store.read
      @stats = LifetimeStats.parse(text, legacy:)
      store.write(stats.to_text) if LifetimeStats.old?(text)
    end

    # Adds a finished round's RoundStats, played on a screen of
    # +size_class+, saves, and says what the round did: the records it set
    # among that class's bests, most impressive first, and whether it was
    # the first to meet today's goal.
    def record(round, size_class)
      day = today
      records = stats.records_set_by(round, size_class)
      goal_met = !stats.streak.done_on?(day) && DailyGoal.for(day).met?(round)
      @stats = stats.add(round, day: day.iso8601, size_class:)
      @stats = stats.with(streak: stats.streak.meet(day)) if goal_met
      @store.write(stats.to_text)
      Result.new(records:, goal_met:)
    end

    def today = @today.call

    # Today's goal, and whether a round has met it yet today.
    def goal = DailyGoal.for(today)
    def goal_done? = stats.streak.done_on?(today)

    # The days in a row, up to today, that the goal was met.
    def streak = stats.streak.current_on(today)

    # What one round did to the lifetime: +records+ (LifetimeStats::Record,
    # most impressive first) and +goal_met+.
    class Result < Data.define(:records, :goal_met); end
  end
end
