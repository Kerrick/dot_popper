# frozen_string_literal: true

module DotPopper
  # One line per finished round, as CSV, for comparing playtests: when it
  # ended, the seed its dots were drawn from, its score, how long it ran,
  # its RoundStats, and the day's goal (DailyGoal, for the date +today+
  # gives) with whether the round met it. It listens to a Cabinet (Cabinet#subscribe) and appends
  # through a store that answers +read+ and +write(text)+, as BestScore
  # does, so it never touches a file system itself.
  #
  # A log whose first line names other columns, because it was written
  # by an older version, is kept whole in a store of its own, named
  # rounds-<when>.csv and made by +archive+, and a new log starts under
  # the current header.
  class PlaytestLog
    COLUMNS = %w[time seed score duration pops slips softened mean_wait longest_wait goal goal_met].freeze

    HEADER = COLUMNS.join(",")

    def initialize(store, clock: -> { Time.now }, today: -> { clock.call.to_date },
                   archive: ->(_name) { BestScore::Memory.new })
      @store = store
      @clock = clock
      @today = today
      @archive = archive
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
      before = current
      before += "\n" unless before.end_with?("\n")
      @store.write("#{before}#{line}\n")
    end

    # The log so far, under the current header: as it was, or new, after
    # setting aside an older log or starting the first.
    def current
      before = @store.read.to_s
      return before if before.lines.first&.chomp == HEADER

      set_aside(before) unless before.strip.empty?
      "#{HEADER}\n"
    end

    def set_aside(old)
      @archive.call("rounds-#{@clock.call.strftime("%Y%m%d-%H%M%S")}.csv").write(old)
    end
  end
end
