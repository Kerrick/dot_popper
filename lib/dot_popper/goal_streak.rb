# frozen_string_literal: true

module DotPopper
  # The days in a row the daily goal was met: +current+ such days up to
  # +last_met+ (an ISO 8601 date, or nil before the first), and the
  # +longest+ run there has ever been. A day missed only starts the count
  # again; the longest run keeps.
  class GoalStreak < Data.define(:current, :longest, :last_met)
    def initialize(current: 0, longest: 0, last_met: nil) = super

    # The streak once the goal is met on +day+. Meeting it again the same
    # day changes nothing.
    def meet(day)
      return self if done_on?(day)

      count = last_met == (day - 1).iso8601 ? current + 1 : 1
      with(current: count, longest: [longest, count].max, last_met: day.iso8601)
    end

    def done_on?(day) = last_met == day.iso8601

    # The streak as it stands on +day+: still whole until the end of the
    # day after it was last met, and nothing once a day has gone by
    # without it.
    def current_on(day) = done_on?(day) || last_met == (day - 1).iso8601 ? current : 0
  end
end
