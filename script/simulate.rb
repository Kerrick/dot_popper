# frozen_string_literal: true

# Plays Dot Popper's real rules with a model player, without a window,
# to see how the size of the field, in radii, changes a round. This is a
# design tool, not a test: its player is a rough model of a person.
#
#   bundle exec ruby script/simulate.rb [rounds]
#
# The model player waits a reaction time, finds the one fresh dot, and
# taps it when it is exposed (no popped dot covers the point it aims at),
# taking Fitts's law time to get there. While the fresh dot is covered it
# waits, and with a small chance per attempt it taps anyway and hits a
# popped dot on top. Simulated at 30 updates a second.
#
# Each device plays in its own Ractor, in parallel, and then again one
# after another, to show the two give the same rounds and how much
# sooner the Ractors finish.

# Ruby 4.0 stops every Ractor for each garbage collection, and a round
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
  GIVE_UP = 240.0         # a round this long counts as endless

  Device = Data.define(:name, :width_r, :height_r, :pointer)

  DEVICES = [
    Device.new("iPhone portrait", 7.9, 17.0, :touch),
    Device.new("iPad 11\"", 16.4, 23.6, :touch),
    Device.new("iPad Pro 13\"", 20.6, 27.5, :touch),
    Device.new("Reference window 24x16R", 24, 16, :mouse),
    Device.new("27\" 1440p fullscreen", 51.2, 28.8, :mouse),
    Device.new("32\" 6K fullscreen", 60.2, 33.8, :mouse)
  ].freeze

  class Player
    def initialize(device, random)
      @device = device
      @random = random
      @r = DotPopper::Rules::RADIUS
      @hand = [0.0, 0.0]
    end

    def play
      field = DotPopper::Field.new(@device.width_r * @r, @device.height_r * @r, @r)
      @hand = [field.width / 2, field.height / 2]
      round = DotPopper::Round.new(field, random: @random)
      t = 0.0
      penalties = 0
      covered_spawns = 0
      until round.over? || t > GIVE_UP
        fresh = round.dots.find(&:fresh?)
        covered_spawns += 1 if covered?(round, fresh)
        busy = REACTION
        busy, t = wait(round, busy, t)
        loop do
          break if round.over?

          fresh = round.dots.find(&:fresh?)
          if covered?(round, fresh) && @random.rand > IMPATIENCE
            round.update(0.1)
            t += 0.1
            next
          end
          travel = fitts(fresh)
          _, t = wait(round, travel, t)
          break if round.over?

          fresh = round.dots.find(&:fresh?)
          aim = [fresh.x, fresh.y]
          event = round.tap_at(*aim)
          @hand = aim
          penalties += 1 if event.is_a?(DotPopper::Events::Penalized)
          break if event.is_a?(DotPopper::Events::Popped)
        end
      end
      { score: round.score, seconds: t, endless: t > GIVE_UP, penalties:, dots: round.dots.size,
        covered: covered_spawns }
    end

    private

    def wait(round, seconds, t)
      steps = (seconds / STEP).ceil
      steps.times { round.update(STEP) unless round.over? }
      [0, t + (steps * STEP)]
    end

    def covered?(round, fresh) = !round.dots.top_at(fresh.x, fresh.y).fresh?

    def fitts(target)
      distance = Math.hypot(target.x - @hand[0], target.y - @hand[1])
      FITTS_A + (FITTS_B.fetch(@device.pointer) * Math.log2((distance / (2 * @r)) + 1))
    end
  end

  # One device's rounds, from its own seeded Random. The same seed gives
  # the same rounds whether they run here or in a Ractor.
  def self.play(device, rounds)
    random = Random.new(2026)
    Array.new(rounds) { Player.new(device, random).play }
  end

  # Every device in its own Ractor. A Ractor shares nothing mutable, so
  # each makes its own Random, Round, and Player; what it reads from
  # outside (DEVICES, the rule numbers) is deeply frozen, and what it
  # returns is copied back.
  def self.play_in_parallel(rounds)
    DEVICES.map { |device| Ractor.new(device, rounds) { |each, count| Simulation.play(each, count) } }.map(&:value)
  end

  def self.play_serially(rounds) = DEVICES.map { play(it, rounds) }

  def self.run(rounds)
    serial, serial_seconds = timed { play_serially(rounds) }
    parallel, parallel_seconds = timed { play_in_parallel(rounds) }
    abort "The Ractors' rounds differ from the serial ones." unless parallel == serial

    report(rounds, parallel)
    puts format("\n%d devices: %.2f s one after another, %.2f s in Ractors, %.1fx as fast (%d cores)",
                DEVICES.size, serial_seconds, parallel_seconds, serial_seconds / parallel_seconds, Etc.nprocessors)
  end

  def self.timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [yield, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  end

  def self.report(rounds, all_results)
    puts format("%-26s %6s %6s %6s %6s %7s %6s", "device", "area", "score", "p90", "secs", "endless", "pen")
    DEVICES.zip(all_results).each do |device, results|
      scores = results.map { it[:score] }.sort
      puts format("%-26s %6.0f %6.1f %6d %6.1f %6.0f%% %6.1f",
                  device.name, device.width_r * device.height_r, scores.sum.fdiv(rounds), scores[(rounds * 0.9).floor],
                  results.sum { it[:seconds] } / rounds, 100.0 * results.count { it[:endless] } / rounds,
                  results.sum { it[:penalties] }.fdiv(rounds))
    end
  end
end

Simulation.run(Integer(ARGV.fetch(0, 200)))
