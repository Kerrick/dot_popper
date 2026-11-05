# frozen_string_literal: true

module DotPopper
  # The best score in one day's Daily on this device. Only today's is
  # kept: the store holds a date and a score, "2026-11-05 27", and a best
  # from another day counts as none. It reads and writes through a store
  # that answers +read+ and +write(text)+, as BestScore does.
  class DailyBest
    def initialize(store)
      @store = store
      day, score = store.read.to_s.split
      @date = parse(day.to_s)
      @score = Integer(score.to_s, exception: false)
    end

    # The best score on +date+, or nil before its first round.
    def value(date) = (@score if @date == date)

    # Records +score+ for +date+ and says whether it beat that day's best.
    def record(date, score)
      best = value(date)
      return false if best && score <= best

      @date = date
      @score = score
      @store.write("#{date.iso8601} #{score}")
      true
    end

    private

    def parse(day)
      Date.iso8601(day)
    rescue ArgumentError # Date::Error, a kind of ArgumentError
      nil
    end
  end
end
