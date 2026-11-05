# frozen_string_literal: true

module DotPopper
  # One line per finished round, as CSV, for comparing playtests: when it
  # ended, the seed its dots were drawn from, its score, how long it ran,
  # its RoundStats, and the day's goal (DailyGoal, for the date +today+
  # gives) with whether the round met it. It listens to a Game (Game#subscribe) and appends
  # through a store that answers +read+ and +write(text)+, as BestScore
  # does, so it never touches a file system itself.
  class PlaytestLog
    COLUMNS = %w[time seed score duration pops slips softened mean_wait longest_wait goal goal_met].freeze

    def initialize(store, clock: -> { Time.now }, today: -> { clock.call.to_date })
      @store = store
      @clock = clock
      @today = today
      @recorder = RoundStats::Recorder.new
    end

    def call(event)
      @recorder.call(event)
      append(row(event, @recorder.stats)) if event.is_a?(Events::RoundEnded)
    end

    private

    def row(ended, stats)
      goal = DailyGoal.for(@today.call)
      [@clock.call.iso8601, ended.seed, ended.score, seconds(stats.duration), stats.pops, stats.slips, stats.softened,
       seconds(stats.mean_wait), seconds(stats.longest_wait), goal, goal.met?(stats)].join(",")
    end

    def seconds(value) = format("%.2f", value)

    def append(line)
      before = @store.read.to_s
      before = "#{COLUMNS.join(",")}\n" if before.empty?
      before += "\n" unless before.end_with?("\n")
      @store.write("#{before}#{line}\n")
    end
  end
end
