# frozen_string_literal: true

module DotPopper
  # This device's LifetimeStats, kept in a store that answers +read+ and
  # +write(text)+, as BestScore's is. +today+ gives the player's local
  # date. A store that is missing or damaged starts from nothing, or from
  # what it could read.
  class Lifetime
    attr_reader :stats

    def initialize(store, today: -> { Date.today })
      @store = store
      @today = today
      @stats = LifetimeStats.parse(store.read)
    end

    # Adds a finished round's RoundStats, saves, and returns the records
    # it set, most impressive first.
    def record(round)
      records = stats.records_set_by(round)
      @stats = stats.add(round, day: today.iso8601)
      @store.write(stats.to_text)
      records
    end

    def today = @today.call
  end
end
