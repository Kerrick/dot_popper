# frozen_string_literal: true

# What a packaged app holds of the game, laid out as `lota fuse` lays it
# out (PACKAGING.md, What goes into the app), and a check that the game
# starts from only that, with no Bundler and no gem but Lota, short of
# opening a window (PackagedApp::START). test/packaged_app_test.rb runs
# the check in `rake test`, so a file the app would not hold, or a library
# it would not have, fails there rather than in a built app.
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "channel_contents"

module PackagedApp
  ROOT = File.expand_path("..", __dir__)

  # The repository's own files, which every app leaves out: the fuse
  # action (.github/actions/fuse/action.yml) passes each to
  # `lota fuse --exclude`, and test/packaged_app_test.rb holds its list to
  # this one.
  REPOSITORY_ONLY = %w[test doc sig script playtest android ios macos windows .github Rakefile Steepfile mise.toml
                       AGENTS.md GLOSSARY.md INSIPIRATION.md PACKAGING.md README.md .gitignore].freeze

  # Run in a Ruby of its own, with the game's folder in the app and then
  # the libraries to require: reads the game's settings as `lota fuse`
  # does (conf.rb), loads main.rb as Lota::Boot does once the window is
  # open, and requires each library the game's code names, which it may
  # require only when it first needs it. Prints what it found, and fails
  # with what it could not load.
  START = <<~RUBY
    game, *libraries = ARGV
    require "lota"
    settings = Lota::Boot.new(game, [], fused: true).read_settings
    puts "identity \#{settings.identity}"
    require File.join(game, "main.rb")
    callbacks = %i[load update draw].select { Lota.respond_to?(it) }
    abort "main.rb defines none of Lota.load, update or draw" if callbacks.empty?
    puts "callbacks \#{callbacks.join(" ")}"
    libraries.each { require it }
    puts "libraries \#{libraries.join(" ")}"
  RUBY

  module_function

  # The paths +channel+'s app leaves out of the game: the repository's
  # own, and what the channel's build leaves out (ChannelContents).
  def excludes(channel) = REPOSITORY_ONLY + ChannelContents.left_out(channel)

  # Lays out in +to+ the game's folder as `lota fuse` copies +game+ into
  # the app, leaving out +excludes+, by Lota's own copy (Lota::Fuse), so
  # that it leaves out exactly what the app does.
  def lay_out(game, to, excludes:)
    require "lota"
    require "lota/fuse"
    out = File.join(Dir.tmpdir, "dot_popper-no-fuse-output")
    Lota::Fuse.new(game, Lota::Fuse.options(exclude: excludes, out:)).send(:copy_game, File.expand_path(game), to)
  end

  # The folders the gems an app ships load from, for a Ruby that has no
  # gems: those of the Gemfile's default group, as `lota fuse` ships them
  # (Lota alone today), or Lota's when Bundler isn't loaded.
  def shipped_load_path
    require "lota"
    specs = defined?(Bundler) ? Bundler.definition.specs_for([:default]).to_a : [Gem.loaded_specs.fetch("lota")]
    specs.reject { it.name == "bundler" }.flat_map(&:full_require_paths)
  end

  # The libraries the Ruby files in +game+ require by name.
  def libraries(game)
    ruby_files(game).flat_map { File.read(it).scan(/^\s*require\s+"([^"#]+)"/).flatten }.uniq.sort
  end

  # The Ruby in +game+: its .rb files, and the programs in bin/.
  def ruby_files(game)
    Dir.glob(File.join(game, "**", "*.rb")) + Dir.glob(File.join(game, "bin", "*")).select { File.file?(it) }
  end

  # Runs START on the laid-out +game+ as a player's computer would; returns
  # the output and whether it passed.
  def start(game) = bare_ruby("-e", START, game, *libraries(game))

  # Runs this Ruby with +arguments+ as the app's Ruby runs: no Bundler, no
  # gem but those the app ships, none of this process's settings, and a
  # home of its own, with +env+ added. Ruby's own default libraries load;
  # its bundled gems, which the app's Ruby also carries, do not, since the
  # game must lock a gem it uses. Returns the output and whether it exited
  # with 0.
  def bare_ruby(*arguments, env: {})
    Dir.mktmpdir("dot_popper-home") do |home|
      gems = File.join(home, "no-gems")
      Dir.mkdir(gems)
      kept = %w[PATH SystemRoot SYSTEMROOT windir TEMP TMP].to_h { [it, ENV.fetch(it, nil)] }.compact
      bare = kept.merge("HOME" => home, "USERPROFILE" => home, "APPDATA" => home, "LOCALAPPDATA" => home,
                        "GEM_HOME" => gems, "GEM_PATH" => gems, "DOT_POPPER_AUTOMATED" => "1")
      load_path = shipped_load_path.flat_map { ["-I", it] }
      out, status = Open3.capture2e(bare.merge(env), RbConfig.ruby, *load_path, *arguments,
                                    unsetenv_others: true, chdir: home)
      [out, status.success?]
    end
  end
end
