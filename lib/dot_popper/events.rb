# frozen_string_literal: true

module DotPopper
  # What the rules report as they happen, for whatever wants to show them.
  # Each is a frozen value, decided before anyone hears of it: by the time
  # a listener runs, the score, the clock, and the dots have already
  # changed.
  module Events
    # A fresh dot was tapped and popped; +spawned+ is the dot that took
    # its place underneath.
    Popped = Data.define(:dot, :x, :y, :points, :seconds, :spawned)

    # A popped dot was tapped. +points+ is what the score actually lost,
    # which is less than the penalty when the score was near zero.
    Penalized = Data.define(:dot, :x, :y, :points, :seconds)

    # A tap hit no dot.
    Missed = Data.define(:x, :y)

    RoundStarted = Data.define(:round)
    RoundEnded = Data.define(:round, :best, :new_best)
    TitleShown = Data.define(:best)
  end
end
