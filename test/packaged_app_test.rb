# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require "yaml"
require_relative "../script/packaged_app"
require_relative "../script/set_build_channel"

# A packaged app holds the game's folder without the repository's own
# files, and a Ruby with no Bundler and no gem but Lota. Each test here
# lays the game out as `lota fuse` does and starts it as the app would,
# short of a window, so a file or a library the app would lack fails here,
# in seconds, and not only once an app is built and played
# (script/play_packaged_app.rb).
class PackagedAppTest < Minitest::Test
  ROOT = PackagedApp::ROOT

  # The one place a file the app leaves out is required by path, and why
  # the app never reaches it: main.rb plays rake test:gui's scenarios
  # only under DOT_POPPER_SCENARIO, which only the GUI suite sets, running
  # the game from the repository.
  REQUIRED_FROM_THE_REPOSITORY_ONLY = { "main.rb" => %r{\Atest/gui/} }.freeze

  def self.laid_out = @laid_out ||= {}

  # The files git tracks, which a checkout of the commit holds, copied once.
  def self.tracked
    @tracked ||= Dir.mktmpdir("dot_popper-tracked").tap do |folder|
      Minitest.after_run { FileUtils.rm_rf(folder) }
      PackagedApp.copy_tracked(folder, except: %w[vendor/cache/])
    end
  end

  # The game's folder in +channel+'s app, laid out once per channel.
  def game(channel = ChannelContents::TEST)
    self.class.laid_out[channel] ||= begin
      folder = File.join(Dir.mktmpdir("dot_popper-app"), "game", "dot_popper")
      Minitest.after_run { FileUtils.rm_rf(File.expand_path("../..", folder)) }
      PackagedApp.lay_out(self.class.tracked, folder, excludes: PackagedApp.excludes(channel))
      unless channel == ChannelContents::TEST
        build = File.join(folder, "lib/dot_popper/build.rb")
        File.write(build, BuildChannel.stamp(File.read(build), channel))
      end
      folder
    end
  end

  def setup
    require "lota"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def test_the_app_leaves_out_the_repositorys_own_files
    held = Dir.children(game)

    assert_includes held, "main.rb"
    assert_includes held, "lib"
    assert_empty held & PackagedApp::REPOSITORY_ONLY
  end

  def test_the_game_starts_from_what_its_app_holds
    out, ok = PackagedApp.start(game)

    assert ok, out
    assert_match(/^identity dot_popper$/, out)
    assert_match(/^callbacks load update draw$/, out)
    assert_match(/^libraries .*\bopenssl\b/, out)
  end

  def test_each_channels_build_starts_from_what_its_app_holds
    DotPopper::Build::CHANNEL_NAMES.each do |channel|
      out, ok = PackagedApp.start(game(channel))

      assert ok, "#{channel}: #{out}"
    end
  end

  # A file required by its path only when something first needs it would
  # not fail as the game starts.
  def test_every_file_the_code_requires_by_its_path_is_in_the_app
    missing = PackagedApp.ruby_files(game).flat_map do |file|
      name = file.delete_prefix("#{game}/")
      File.read(file).scan(/^\s*require_relative\s+"([^"#]+)"/).flatten.filter_map do |required|
        path = File.expand_path(required, File.dirname(file)).delete_prefix("#{game}/")
        path += ".rb" unless path.end_with?(".rb")
        next if File.file?(File.join(game, path)) || REQUIRED_FROM_THE_REPOSITORY_ONLY[name]&.match?(path)

        "#{name} requires #{path}"
      end
    end

    assert_empty missing
  end

  # Fonts, shaders and images are read by their paths in the game's
  # folder only when drawn.
  def test_every_asset_the_code_names_is_in_the_app
    named = PackagedApp.ruby_files(game).flat_map { File.read(it).scan(%r{"(assets/[^"]*)"}).flatten }.uniq

    assert_operator named.size, :>, 5
    missing = named.reject { Dir.glob(File.join(game, it.gsub(/#\{[^}]*\}/, "*"))).any? }

    assert_empty missing
  end

  # bin/dot_popper is the program the iPhone and iPad apps run (PACKAGING.md),
  # and names Lota's classes itself.
  def test_the_phones_program_finds_lota_and_the_game
    report = File.join(Dir.mktmpdir("dot_popper-smoke"), "smoke.txt")
    out, ok = PackagedApp.bare_ruby(File.join(game, "bin", "dot_popper"), env: { "DOT_POPPER_SMOKE" => report })

    assert ok, "#{out}#{File.read(report) if File.file?(report)}"
    assert_match(/^callbacks load update draw$/, File.read(report))
  ensure
    FileUtils.rm_rf(File.dirname(report)) if report
  end

  def test_the_fuse_action_leaves_out_the_repositorys_own_files
    steps = YAML.load_file(File.join(ROOT, ".github/actions/fuse/action.yml")).dig("runs", "steps")
    script = steps.find { it["name"] == "lota fuse" }.fetch("run")
    listed = script[/for path in (.*?); do/m, 1].to_s.delete("\\").split

    assert_equal PackagedApp::REPOSITORY_ONLY, listed
  end
end
