# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "shellwords"
require "tmpdir"

# The Ruby half of the Android emulator checks, without Android. The
# Android app runs android/android_kit, which runs the game's
# bin/dot_popper from the game's files the app carries
# (script/android_game.sh), and only a phone or an emulator runs them.
# A name renamed in the game but not in the kit, a file the app leaves
# out that the game loads, or a line the checks wait for that the game
# no longer prints would otherwise show only there. So each run of
# .github/android_emulator_checks.sh is played here, with the same
# settings, keys and expectations, on a stand-in for Lota on Android
# (test/android/fake_android/lota.rb), and must pass as it must there.
# What only Android does (the host starting Ruby, drawing, the activity's
# life, Back trapped as Escape) is the emulator's to check.
class KitTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  CHECKS = File.join(ROOT, ".github/android_emulator_checks.sh")
  FAKE = File.join(__dir__, "fake_android")

  # Options of android_emulator.rb that take no value.
  FLAGS = %w[--pop --until-met].freeze

  # One run of android_emulator.rb in the checks script: its name (its
  # folder under OUT) and its options, each with its value, or nil.
  Run = Data.define(:name, :options)

  def self.pairs(words)
    words = words.dup
    pairs = []
    pairs << [words.first, FLAGS.include?(words.shift) ? nil : words.shift] until words.empty?
    pairs
  end

  def self.runs(script = File.read(CHECKS))
    script.gsub("\\\n", " ").lines.filter_map { it[%r{ruby "\$here/android_emulator\.rb".*}] }.map do |line|
      words = Shellwords.split(line.split(/\s\|\|\s/).first)
      Run.new(name: File.basename(words.fetch(4)), options: pairs(words.drop(5)))
    end
  end

  def self.project
    @project ||= Dir.mktmpdir("dot-popper-phone").tap do |folder|
      Minitest.after_run { FileUtils.rm_rf(folder) }
      out, status = Open3.capture2e("bash", File.join(ROOT, "script/android_game.sh"), "--worktree", folder)
      raise "script/android_game.sh failed: #{out}" unless status.success?
    end
  end

  # The Android app is built on Linux, and its game laid out with bash
  # and tar, which take a Windows path for a remote one.
  def setup
    skip "the Android app's game is laid out on Linux or macOS" if Gem.win_platform?
  end

  def test_the_checks_script_runs_the_three_checks
    assert_equal %w[autoplay back-on-title foreground], self.class.runs.map(&:name)
  end

  runs.each do |run|
    define_method(:"test_the_#{run.name.tr('-', '_')}_check_passes_on_the_game_the_app_carries") do
      lines, status = play(run)
      failures = Expectations.new(run.options).failures(lines)
      assert_empty failures, "#{run.name}, exit #{status}:\n#{lines.last(40).join("\n")}"
    end
  end

  # What android_emulator.rb requires of the app's lines, and what it
  # sends: every --expect on some line, the --expect-order ones in order,
  # each --key-after sent, and no "kit probe: error".
  class Expectations
    def initialize(options)
      @expects = []
      @ordered = []
      @keys = []
      options.each do |option, value|
        case option
        when "--expect" then @expects << Regexp.new(value)
        when "--expect-order" then @ordered << Regexp.new(value)
        when "--key-after" then @keys << value.split(":", 3)
        end
      end
    end

    def failures(lines)
      failures = []
      failures.concat(lines.grep(/kit probe: error/))
      @expects.each { |pattern| failures << "missing: #{pattern.source}" unless lines.any? { pattern.match?(it) } }
      rest = lines
      @ordered.each do |pattern|
        index = rest.index { pattern.match?(it) }
        next rest = rest.drop(index + 1) if index

        failures << "missing, in order: #{pattern.source}"
        break
      end
      @keys.each { |(_, code, pattern)| failures << "never sent #{code}: no line matched #{pattern}" unless lines.include?("fake android: sent #{code}") }
      failures
    end
  end

  private

  # Plays +run+ on the fake Android: its --env settings, and what its
  # keys and shell commands do, when its lines say to.
  def play(run)
    # Only the run's own settings, as on the emulator: none of this
    # process's, and no Bundler, which the app has none of.
    env = ENV.keys.grep(/\A(DOT_POPPER_|BUNDLE_|RUBY)/).to_h { [it, nil] }
    env["FAKE_ANDROID_DRIVE"] = JSON.generate(drive(run.options))
    run.options.each { |option, value| env.store(*value.split("=", 2)) if option == "--env" }
    out, status = Open3.capture2e(env, RbConfig.ruby, "-I", FAKE, "main.rb", chdir: self.class.project)
    [out.lines.map(&:chomp), status.exitstatus]
  end

  def drive(options)
    drive = { "keys" => [], "shells" => [] }
    options.each do |option, value|
      case option
      when "--key-after" then drive["keys"] << value.split(":", 3).then { |seconds, code, pattern| [Float(seconds), code, pattern] }
      when "--shell" then drive["shells"] << value.split(":", 2).then { |seconds, command| [Float(seconds), command] }
      when "--ready" then drive["ready"] = value
      when "--timeout" then drive["timeout"] = Float(value)
      end
    end
    drive
  end
end
