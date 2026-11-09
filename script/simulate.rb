# frozen_string_literal: true

# Plays Dot Popper's real rules with a model player, without a window,
# to see how the size of the field, in radii, changes a game. This is a
# design tool, not a test: its player is a rough model of a person.
#
#   bundle exec ruby script/simulate.rb [games]
#
# The model player waits a reaction time, finds the one fresh dot, and
# taps it when it is exposed (no popped dot covers the point it aims at),
# taking Fitts's law time to get there. While the fresh dot is covered it
# waits, and with a small chance per attempt it taps anyway and hits a
# popped dot on top. Simulated at 30 updates a second.
#
# Run it as "bundle exec ruby script/simulate.rb bonus [games [streaks
# [points [seconds]]]]", each list comma-separated, to compare
# candidate numbers for the streak's bonus dot (Rules::Bonus) on three
# devices instead: score, game length, how often a game is endless, how
# many bonus dots a game earns, and how many of the day's goals
# (DailyGoal) a game meets, for each candidate and without a bonus dot.
#
# Every device plays with each choice of dot size (DotSizing): the
# standard size, as the spec has it, and sized to the screen. Each plays
# twice, with the spawn rule (Spawner) and without it, to show how often
# a new dot is redrawn and what that does to the score. Each run plays in
# its own Ractor, in parallel, and then again one after
# another, to show the two give the same games and how much sooner the
# Ractors finish.

# Ruby 4.0 stops every Ractor for each garbage collection, and a game
# makes a great deal of short-lived garbage: new dots and stacks every
# step. With Ruby's default starting heap that is about a thousand
# collections, and the Ractors spend their time waiting for one another;
# with a million slots in each of the three smallest size pools (about
# 250 MB), it is a few dozen. So the script runs itself again with that.
GC_HEAP = (0..2).to_h { ["RUBY_GC_HEAP_#{it}_INIT_SLOTS", "1000000"] }.freeze
exec(GC_HEAP, RbConfig.ruby, __FILE__, *ARGV) unless GC_HEAP.all? { |name, slots| ENV[name] == slots }

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dot_popper"
require "etc"

Warning[:experimental] = false # Ractors still warn that their API may change.

module Simulation
  STEP = 1.0 / 30
  REACTION = 0.25          # seconds to notice a new fresh dot
  FITTS_A = 0.10           # seconds
  FITTS_B = { mouse: 0.15, touch: 0.12 }.freeze # seconds per bit
  IMPATIENCE = 0.04        # chance per 0.1 s of waiting to tap a covered dot
  GIVE_UP = 240.0         # a game this long counts as endless

  Device = Data.define(:name, :width_r, :height_r, :pointer)

  DEVICES = [
    Device.new("iPhone portrait", 7.9, 17.0, :touch),
    Device.new("iPad 11\"", 16.4, 23.6, :touch),
    Device.new("iPad Pro 13\"", 20.6, 27.5, :touch),
    Device.new("Reference window 24x16R", 24, 16, :mouse),
    Device.new("27\" 1440p fullscreen", 51.2, 28.8, :mouse),
    Device.new("32\" 6K fullscreen", 60.2, 33.8, :mouse)
  ].freeze

  # How one game went. +covered+ counts the fresh dots that spawned
  # under a popped one; +spawns+, how each was drawn (DotPopper::Spawn).
  Result = Data.define(:score, :seconds, :penalties, :dots, :covered, :spawns, :stats) do
    def endless? = seconds > GIVE_UP
    def count(&) = spawns.count(&)
  end

  SIZINGS = [DotPopper::DotSizing::STANDARD, DotPopper::DotSizing::SIZED_TO_SCREEN].freeze

  # One device with one choice of dot size, and the spawn rule's tries
  # (0 turns it off).
  Job = Data.define(:device, :sizing, :spawn_tries, :bonus) do
    def initialize(device:, sizing:, spawn_tries:, bonus: DotPopper::Rules::BONUS) = super

    # The field a game starts on: the device's screen in graphics
    # units, as the game would see it, with the dots sized as chosen.
    def field
      r = DotPopper::Rules::RADIUS
      sizing.fit(DotPopper::Field.new(device.width_r * r, device.height_r * r, r))
    end
  end

  TRIES = [DotPopper::Rules::SPAWN_TRIES, 0].freeze

  JOBS = SIZINGS.flat_map { |sizing| DEVICES.flat_map { |device| TRIES.map { Job.new(device:, sizing:, spawn_tries: it) } } }.freeze

  class Player
    def initialize(job, random)
      @device = job.device
      @field = job.field
      @spawn_tries = job.spawn_tries
      @bonus = job.bonus
      @random = random
      @r = @field.radius
      @hand = [0.0, 0.0]
    end

    def play
      field = @field
      @hand = [field.width / 2, field.height / 2]
      game = DotPopper::Game.new(field, random: @random, spawn_tries: @spawn_tries, bonus: @bonus)
      stats = DotPopper::GameStats.start
      t = 0.0
      penalties = 0
      covered_spawns = 0
      until game.over? || t > GIVE_UP
        fresh = game.dots.find(&:fresh?)
        covered_spawns += 1 if covered?(game, fresh)
        t = wait(game, REACTION, t)
        loop do
          break if game.over?

          fresh = game.dots.find(&:fresh?)
          if covered?(game, fresh) && @random.rand > IMPATIENCE
            game.update(0.1)
            t += 0.1
            next
          end
          travel = fitts(fresh)
          t = wait(game, travel, t)
          break if game.over?

          fresh = game.dots.find(&:fresh?)
          aim = [fresh.x, fresh.y]
          event = game.tap_at(*aim)
          stats = stats.record(event, at: game.elapsed) if event
          @hand = aim
          case event
          in DotPopper::Events::Popped then break
          in DotPopper::Events::Penalized then penalties += 1
          in DotPopper::Events::Missed | nil then next
          end
        end
      end
      Result.new(score: game.score, seconds: t, penalties:, dots: game.dots.size, covered: covered_spawns,
                 spawns: game.spawns, stats: stats.with(duration: game.elapsed))
    end

    private

    def wait(game, seconds, t)
      steps = (seconds / STEP).ceil
      steps.times { game.update(STEP) unless game.over? }
      t + (steps * STEP)
    end

    def covered?(game, fresh) = !game.dots.top_at(fresh.x, fresh.y).fresh?

    def fitts(target)
      distance = Math.hypot(target.x - @hand[0], target.y - @hand[1])
      FITTS_A + (FITTS_B.fetch(@device.pointer) * Math.log2((distance / (2 * @r)) + 1))
    end
  end

  # One job's games, from its own seeded Random. The same seed gives the
  # same games whether they run here or in a Ractor.
  def self.play(job, games)
    random = Random.new(2026)
    Array.new(games) { Player.new(job, random).play }
  end

  # Every job in its own Ractor. A Ractor shares nothing mutable, so each
  # makes its own Random, Game, and Player; what it reads from outside
  # (JOBS, the rule numbers) is deeply frozen, and what it returns is
  # copied back.
  def self.play_in_parallel(games)
    JOBS.map { |job| Ractor.new(job, games) { |each, count| Simulation.play(each, count) } }.map(&:value)
  end

  def self.play_serially(games) = JOBS.map { play(it, games) }

  def self.run(games)
    serial, serial_seconds = timed { play_serially(games) }
    parallel, parallel_seconds = timed { play_in_parallel(games) }
    abort "The Ractors' games differ from the serial ones." unless parallel == serial

    report(games, parallel)
    puts format("\n%d runs: %.2f s one after another, %.2f s in Ractors, %.1fx as fast (%d cores)",
                JOBS.size, serial_seconds, parallel_seconds, serial_seconds / parallel_seconds, Etc.nprocessors)
  end

  def self.timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [yield, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  end

  # A table for each choice of dot size: each device's radius, its
  # field's area in square radii, and how its games went with the spawn
  # rule. "redrawn" and "moved" are the share of spawns whose velocity,
  # and then place, were drawn again; "no target" is the share of spawns
  # without the rule that offered no touch target for a second, and
  # "old score" the mean score without it.
  def self.report(games, all_results)
    JOBS.zip(all_results).group_by { |job, _| job.sizing }.each do |sizing, rows|
      puts sizing.sized_to_screen? ? "\nDots sized to the screen" : "\nStandard dot size"
      puts format("%-26s %6s %6s %6s %6s %6s %7s %6s %8s %7s %9s %9s", "device", "R", "area", "score", "p90", "secs",
                  "endless", "pen", "redrawn", "moved", "no target", "old score")
      rows.each_slice(TRIES.size) { |(job, results), (_, unruled)| report_row(job, results, unruled, games) }
    end
  end

  def self.report_row(job, results, unruled, games)
    field = job.field
    scores = results.map(&:score).sort
    puts format("%-26s %6.1f %6.0f %6.1f %6d %6.1f %6.0f%% %6.1f %7.2f%% %6.2f%% %8.2f%% %9.1f",
                job.device.name, field.radius, field.width * field.height / (field.radius**2),
                scores.sum.fdiv(games), scores[(games * 0.9).floor], results.sum(&:seconds) / games,
                100.0 * results.count(&:endless?) / games, results.sum(&:penalties).fdiv(games),
                share(results, &:redrawn?), share(results, &:moved?), share(unruled, &:exhausted?),
                unruled.sum(&:score).fdiv(games))
  end

  # The percentage of all the spawns in +results+ for which the block holds.
  def self.share(results, &)
    100.0 * results.sum { it.count(&) } / results.sum { it.spawns.size }
  end

  # The streak lengths, bonus points and bonus seconds to compare.
  # With no lists given: streaks of 6 to 12, 2 or 4 points, 2, 4 or 6 seconds.
  def self.candidates(streaks, points, seconds)
    [nil, *streaks.product(points, seconds).map { |args| DotPopper::Rules::Bonus.new(*args) }]
  end

  def self.numbers(text, default, convert) = text ? text.split(",").map { convert.call(it) } : default

  BONUS_DEVICES = DEVICES.values_at(0, 3, 4).freeze

  def self.compare_bonuses(games, streaks: nil, points: nil, seconds: nil)
    list = candidates(numbers(streaks, [6, 8, 10, 12], :to_i.to_proc), numbers(points, [2, 4], :to_i.to_proc),
                      numbers(seconds, [2.0, 4.0, 6.0], :to_f.to_proc))
    jobs = BONUS_DEVICES.flat_map do |device|
      list.map { Job.new(device:, sizing: DotPopper::DotSizing::SIZED_TO_SCREEN, spawn_tries: DotPopper::Rules::SPAWN_TRIES, bonus: it) }
    end
    results = jobs.map { |job| Ractor.new(job, games) { |each, count| Simulation.play(each, count) } }.map(&:value)
    jobs.zip(results).group_by { |job, _| job.device }.each do |device, rows|
      puts "\n#{device.name}"
      puts format("%-18s %6s %5s %6s %6s %7s %6s %6s  %s", "bonus (n/pts/s)", "score", "p90", "secs", "p90s", "endless",
                  "pen", "bonus", DotPopper::DailyGoal::LIST.map { "#{it.kind}".ljust(12) }.join)
      rows.each { |job, each| compare_row(job.bonus, each, games) }
    end
  end

  def self.compare_row(bonus, results, games)
    scores = results.map(&:score).sort
    times = results.map(&:seconds).sort
    goals = DotPopper::DailyGoal::LIST.map { |goal| format("%-12s", format("%.0f%%", 100.0 * results.count { goal.met?(it.stats) } / games)) }
    name = bonus ? "#{bonus.streak}/#{bonus.points}/#{bonus.seconds.to_i}" : "none"
    puts format("%-18s %6.1f %5d %6.1f %6.1f %6.0f%% %6.1f %6.2f  %s", name, scores.sum.fdiv(games), scores[(games * 0.9).floor],
                times.sum / games, times[(games * 0.9).floor], 100.0 * results.count(&:endless?) / games,
                results.sum(&:penalties).fdiv(games), results.sum { it.stats.bonuses }.fdiv(games), goals.join)
  end
end

if ARGV.first == "bonus"
  Simulation.compare_bonuses(Integer(ARGV.fetch(1, 200)), streaks: ARGV[2], points: ARGV[3], seconds: ARGV[4])
else
  Simulation.run(Integer(ARGV.fetch(0, 200)))
end
