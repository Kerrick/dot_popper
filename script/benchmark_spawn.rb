# frozen_string_literal: true

# Times the spawn rule (DotPopper::Spawner) with 100 popped dots on the
# field, about as many as a long game on a big monitor ends with. A
# spawn happens once per pop, so it only has to be quick next to a frame.
# It counts the CPU time of this thread, so a busy machine skews it less.
#
#   bundle exec ruby script/benchmark_spawn.rb [spawns]

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dot_popper"

module SpawnBenchmark
  DOTS = 100
  R = DotPopper::Rules::RADIUS

  FIELDS = {
    "27\" 1440p fullscreen, 1475 R²" => DotPopper::Field.new(51.2 * R, 28.8 * R, R),
    "32\" 6K standard dots, R 115" => DotPopper::Field.new(60.2 * R, 33.8 * R, 115.1),
    "Desktop window, 384 R², crowded" => DotPopper::Field.new(24 * R, 16 * R, R),
    "iPhone portrait, 134 R², full" => DotPopper::Field.new(7.9 * R, 17 * R, R),
    "iPhone standard dots, R 30, full" => DotPopper::Field.new(7.9 * R, 17 * R, 30)
  }.freeze

  def self.run(spawns)
    puts format("%-32s %8s %8s %8s %8s %8s", "#{DOTS} popped dots on", "mean ms", "p99 ms", "max ms", "redrawn", "gave up")
    FIELDS.each { |name, field| report(name, field, spawns) }
  end

  def self.report(name, field, spawns)
    random = Random.new(2026)
    spawner = DotPopper::Spawner.for(field)
    times = []
    results = Array.new(spawns) do |id|
      above = Array.new(DOTS) { DotPopper::Dot.spawn(field, random, id:).pop }
      started = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
      spawner.spawn(random, id:, above:).tap { times << (Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - started) }
    end
    times.sort!
    puts format("%-32s %8.3f %8.3f %8.3f %7.1f%% %7.1f%%", name, 1000 * times.sum / spawns,
                1000 * times[(spawns * 0.99).floor], 1000 * times.last,
                100.0 * results.count(&:redrawn?) / spawns, 100.0 * results.count(&:exhausted?) / spawns)
  end
end

SpawnBenchmark.run(Integer(ARGV.fetch(0, 500)))
