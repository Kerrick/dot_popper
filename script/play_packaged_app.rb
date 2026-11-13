# frozen_string_literal: true

# Plays the Linux app this working copy would ship, as CI's Package
# workflow plays the app it built: the game with no Ruby on its PATH and an
# all but empty environment, on a virtual display (Xvfb), with Mesa's
# software OpenGL, the bot playing, and sounds going nowhere. It passes
# only if the app exits with 0, draws frames, and verifies Ed25519 with its
# own OpenSSL. A run leaves nothing behind but its cache.
#
#   ruby script/play_packaged_app.rb [--seconds 20] [--channel test]
#   ruby script/play_packaged_app.rb --archive "Dot Popper-x86_64-linux.tar.gz"
#
# Fast after the first run: `lota fuse` builds the app around the game,
# which takes minutes, and only the game's folder (app/game/dot_popper)
# differs between two builds whose Lota gem, Gemfile, lockfile, fuse
# options, icon, name and identity are the same. So the first run fuses
# and keeps the app without the game in the cache, under a key made of all
# of those; a later run with the same key copies it, lays the game's files
# in as `lota fuse` copies them (PackagedApp.lay_out, Lota's own copy), and
# plays. Each fuse also checks that its own game folder is the one
# lay_out makes of the same files, so a Lota whose copy differs fails
# rather than passing on a stale app. What is fused and laid out is what
# git tracks, as in a checkout of the commit: other files in the working
# copy never reach the app. The cache is
# $XDG_CACHE_HOME/dot_popper/packaged-app (~/.cache without it), safe for
# runs at once; its three newest apps are kept.
#
# --channel stamps the build for a channel (script/set_build_channel.rb)
# and leaves out what it leaves out (script/channel_contents.rb).
# --archive plays an app that was already built, as CI's Linux job does.
#
# Needs Linux x86_64, git, tar and Xvfb; and for a fuse, the network:
# Bundler fetches Fledge from GitHub and gem checksums from RubyGems.org,
# and Fledge its runtime the first time (PACKAGING.md).
require "digest"
require "fileutils"
require "optparse"
require "rbconfig"
require "timeout"
require "tmpdir"
require "yaml"
require_relative "packaged_app"
require_relative "set_build_channel"

module PlayPackagedApp
  ROOT = PackagedApp::ROOT
  PLATFORM = "x86_64-linux-gnu"
  IDENTIFIER = "com.setdef.DotPopper"
  ICON = "icons/icon"
  KEPT = 3
  # What CI's Package workflow plays with (PLAY_ENV), but the save folder.
  PLAY_ENV = { "ALSOFT_DRIVERS" => "null", "DOT_POPPER_AUTOPLAY" => "1", "DOT_POPPER_SEED" => "7", "DOT_POPPER_PERF" => "1",
               "LIBGL_ALWAYS_SOFTWARE" => "1", "DOT_POPPER_SAVE_AS" => "play-packaged-app" }.freeze
  # What a passing run prints, and why each matters.
  EXPECTED = { /frames a second/ => "the game never reported drawing a frame",
               /Ed25519 verifies the server's test vector/ => "the app's own Ruby does not verify Ed25519" }.freeze
  PLAY_LIMIT = 120
  FUSE_LIMIT = 900

  class Failure < StandardError; end

  module_function

  def main(argv)
    options = { seconds: 20, channel: ChannelContents::TEST, archive: nil }
    OptionParser.new do |parser|
      parser.banner = "usage: ruby script/play_packaged_app.rb [--seconds N] [--channel CHANNEL] [--archive APP.tar.gz]"
      parser.on("--seconds N", Integer, "how long the bot plays (20, as CI)") { options[:seconds] = it }
      parser.on("--channel CHANNEL", ChannelContents::CHANNELS, "the build's channel (test)") { options[:channel] = it }
      parser.on("--archive FILE", "play this built app instead of this working copy's") { options[:archive] = it }
    end.parse!(argv)
    abort "#{$PROGRAM_NAME} plays the Linux x86_64 app only; CI plays the others" unless RUBY_PLATFORM.match?(/x86_64-linux/)

    started = clock
    Dir.mktmpdir("dot_popper-play") do |work|
      app = options[:archive] ? unpack(options[:archive], work) : assemble(work, options[:channel])
      play(app, work, options[:seconds])
    end
    puts "Played the packaged app in #{(clock - started).round(1)} s."
  rescue Failure => e
    warn "play_packaged_app: #{e.message}"
    exit 1
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def step(what)
    started = clock
    result = yield
    puts format("%-48s %6.1f s", what, clock - started)
    result
  end

  def cache = File.join(ENV.fetch("XDG_CACHE_HOME") { File.join(Dir.home, ".cache") }, "dot_popper", "packaged-app")

  # The app this working copy would ship, in +work+.
  def assemble(work, channel)
    stage = step("Copied the files git tracks") { stage(work, channel) }
    lota = step("Lota's release gem") { lota_gem }
    Gem.use_paths(lota.last, [lota.last])
    key, identity = step("Read what the app's build depends on") { key(stage, lota, channel) }
    base = File.join(cache, "apps", key)
    loop do
      fuse(stage, lota, base, identity, work, channel) unless File.directory?(base)
      # A run that finds the app gone, taken by forget_old in between, fuses again.
      app = File.open("#{base}.lock", File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_SH)
        step("Copied the app and laid out the game") { copy(base, stage, work, channel) } if File.directory?(base)
      end
      return app.tap { forget_old } if app
    end
  end

  # The files git tracks, copied to work/stage, with build.rb stamped
  # for +channel+.
  def stage(work, channel)
    stage = PackagedApp.copy_tracked(File.join(work, "stage"))
    unless channel == ChannelContents::TEST
      build = File.join(stage, "lib/dot_popper/build.rb")
      File.write(build, BuildChannel.stamp(File.read(build), channel))
    end
    stage
  end

  # Lota's gem for this platform from vendor/cache, checked against the
  # checksum Gemfile.lock pins, installed once into the cache: [its
  # SHA-256, the folder it is installed in].
  def lota_gem
    lock = File.read(File.join(ROOT, "Gemfile.lock"))
    version, sha = lock.match(/^  lota \(([^)-]+)-#{PLATFORM}\) sha256=(\h+)$/)&.captures
    raise Failure, "Gemfile.lock pins no checksum for lota on #{PLATFORM}" unless sha

    file = File.join(ROOT, "vendor", "cache", "lota-#{version}-#{PLATFORM}.gem")
    raise Failure, "#{file} is not the gem Gemfile.lock pins" unless File.file?(file) && Digest::SHA256.file(file).hexdigest == sha

    home = File.join(cache, "lota", sha)
    once(home) do |into|
      run({}, RbConfig.ruby, File.join(RbConfig::CONFIG["bindir"], "gem"), "install", "--local", "--no-document", "--install-dir", into, file, what: "gem install lota")
    end
    [sha, home]
  end

  # Makes +folder+ with the block, given a fresh folder beside it, unless
  # another run already has; one run at a time makes each.
  def once(folder)
    return if File.directory?(folder)

    FileUtils.mkdir_p(File.dirname(folder))
    File.open("#{folder}.lock", File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      return if File.directory?(folder)

      making = "#{folder}.making-#{Process.pid}"
      FileUtils.rm_rf(making)
      FileUtils.mkdir_p(making)
      yield making
      File.rename(making, folder)
    ensure
      FileUtils.rm_rf(making) if making
    end
  end

  # The cache's key for the app around the game in +stage+: every input of
  # `lota fuse` but the game's own folder.
  def key(stage, lota, channel)
    sha, home = lota
    settings, ok = bare(home, "-e", <<~RUBY, stage)
      require "lota"
      settings = Lota::Boot.new(ARGV[0]).read_settings
      puts settings.identity, settings.window.title
    RUBY
    raise Failure, "the game's conf.rb did not load:\n#{settings}" unless ok

    identity, title = settings.lines.last(2).map(&:chomp)
    files = %w[Gemfile Gemfile.lock] + Dir.glob("#{ICON}*", base: stage).sort +
            Dir.glob("vendor/cache/*.gem", base: stage).sort
    parts = ["lota #{sha}", "fledge #{ENV.fetch("LOTA_FLEDGE_REF", "")}", "ruby #{RUBY_VERSION} #{RUBY_PLATFORM}",
             "identity #{identity}", "title #{title}", *fuse_options(stage, channel),
             *files.map { "#{it} #{Digest::SHA256.file(File.join(stage, it)).hexdigest}" },
             "script #{Digest::SHA256.file(__FILE__).hexdigest}"]
    [Digest::SHA256.hexdigest(parts.join("\n"))[0, 32], identity]
  end

  def fuse_options(stage, channel)
    version = YAML.load_file(File.join(stage, "fledge.yml")).fetch("version").to_s
    excludes = PackagedApp.excludes(channel).flat_map { ["--exclude", it] }
    [*excludes, "--identifier", IDENTIFIER, "--app-version", version, "--icon", ICON]
  end

  # Fuses the game in +stage+ with `lota fuse`, as the fuse action does,
  # and keeps the unpacked app, without the game's files, in +base+.
  def fuse(stage, lota, base, identity, work, channel)
    _, home = lota
    once(base) do |into|
      out = File.join(work, "fuse")
      step("Fused the app with lota fuse (once for this key)") do
        gems = File.join(work, "fuse-gems")
        run({ "GEM_HOME" => gems, "GEM_PATH" => "#{gems}:#{home}" }, RbConfig.ruby, File.join(home, "bin", "lota"), "fuse", stage,
            *fuse_options(stage, channel), "--out", out, what: "lota fuse", limit: FUSE_LIMIT, chdir: work)
      end
      archive = Dir.glob(File.join(out, "*.tar.gz")).first or raise Failure, "lota fuse made no .tar.gz"
      app = step("Unpacked it") { unpack(archive, work) }
      laid = File.join(work, "laid-out", "game")
      lay_out(stage, laid, channel)
      game = File.join(app, "app", "game", Lota::Fuse.folder_name(identity))
      differs = (tree(game) - tree(laid)) + (tree(laid) - tree(game))
      unless differs.empty?
        raise Failure, "the game's folder lota fuse made differs from PackagedApp.lay_out's of the same files:\n" +
                       differs.sort.first(10).map { |path, sha, mode| format("  %s %s %o", path, sha[0, 12], mode) }.join("\n")
      end

      FileUtils.rm_rf(game)
      FileUtils.mkdir_p(game)
      File.rename(app, into.tap { Dir.rmdir(it) })
    end
  end

  # Each file under +folder+, by its path there, with its SHA-256 and mode.
  def tree(folder)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: folder).sort.filter_map do |path|
      file = File.join(folder, path)
      [path, Digest::SHA256.file(file).hexdigest, File.stat(file).mode] if File.file?(file)
    end
  end

  # The app in +base+, copied to work/play, with the game laid out in it.
  def copy(base, stage, work, channel)
    app = File.join(work, "play", "My Games", "Dot Popper-x86_64-linux")
    FileUtils.mkdir_p(File.dirname(app))
    run({}, "cp", "-a", "--reflink=auto", base, app, what: "cp")
    FileUtils.touch(base)
    game = Dir.glob(File.join(app, "app", "game", "*")).first
    lay_out(stage, game, channel)
    app
  end

  # The game laid out in +to+ as the app holds it: Fledge's app gives each
  # file 0755 if its owner may run it and 0644 if not, whatever the
  # working copy's umask made of it.
  def lay_out(stage, to, channel)
    PackagedApp.lay_out(stage, to, excludes: PackagedApp.excludes(channel))
    Dir.glob("**/*", File::FNM_DOTMATCH, base: to).each do |path|
      file = File.join(to, path)
      File.chmod(File.directory?(file) || File.stat(file).mode.anybits?(0o100) ? 0o755 : 0o644, file) unless File.symlink?(file)
    end
  end

  # Removes all but the KEPT newest apps in the cache.
  def forget_old
    apps = Dir.glob(File.join(cache, "apps", "*")).select { File.directory?(it) && !it.match?(/\.(making|gone)-/) }
    apps.sort_by { -File.mtime(it).to_f }.drop(KEPT).each do |old|
      File.open("#{old}.lock", File::RDWR | File::CREAT) do |lock|
        next unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        gone = "#{old}.gone-#{Process.pid}"
        File.rename(old, gone)
        FileUtils.rm_rf(gone)
      end
    end
  end

  def unpack(archive, work)
    into = File.join(work, "unpacked")
    FileUtils.mkdir_p(into)
    run({}, "tar", "-xzf", File.expand_path(archive), "-C", into, what: "tar")
    Dir.glob(File.join(into, "*")).find { File.executable?(File.join(it, "Dot Popper")) } or
      raise Failure, "#{archive} holds no program named Dot Popper"
  end

  # Plays the app in +app+ for +seconds+ on a display of its own.
  def play(app, work, seconds)
    home = File.join(work, "home")
    FileUtils.mkdir_p(home)
    log = File.join(work, "play.txt")
    status = step("Played it for #{seconds} s of the game's time") do
      with_display(work) do |display|
        env = PLAY_ENV.merge("HOME" => home, "PATH" => "/usr/bin:/bin", "DISPLAY" => display,
                             "DOT_POPPER_QUIT_AFTER" => seconds.to_s)
        bounded(env, File.join(app, "Dot Popper"), limit: PLAY_LIMIT, out: log, unsetenv_others: true, chdir: home)
      end
    end
    out = File.read(log)
    puts out.lines.grep(/Ed25519|frames a second|renderer|Error|error/).first(8)
    problems = EXPECTED.reject { |line, _| out.match?(line) }.values
    problems.unshift("the app exited with status #{status.inspect}") unless status&.success?
    return if problems.empty?

    raise Failure, "#{problems.join("; ")}. Its output:\n#{out.lines.last(40).join}"
  end

  # Runs the block with an X display of Xvfb's own, which Xvfb chooses
  # from those free (-displayfd), so runs at once never meet.
  def with_display(work)
    reader, writer = IO.pipe
    log = File.join(work, "xvfb.txt")
    xvfb = spawn("Xvfb", "-displayfd", writer.fileno.to_s, "-screen", "0", "1280x800x24", "-nolisten", "tcp",
                 writer.fileno => writer, %i[out err] => log, pgroup: true)
    writer.close
    number = Timeout.timeout(30) { reader.gets }
    raise Failure, "Xvfb did not start:\n#{File.read(log)}" unless number

    yield ":#{number.strip}"
  rescue Timeout::Error
    raise Failure, "Xvfb did not start within 30 s:\n#{File.read(log)}"
  ensure
    reader&.close
    stop(xvfb) if xvfb
  end

  # Runs a command, with +env+, to its end or +limit+ seconds, then stops
  # it and everything it started. Answers its status, or nil if stopped.
  def bounded(env, *command, limit:, out: File::NULL, **options)
    # [program, program]: a path with a space is a program, not a shell's line.
    pid = spawn(env, [command.first, command.first], *command.drop(1), in: File::NULL, %i[out err] => out, pgroup: true, **options)
    Timeout.timeout(limit) { Process.wait2(pid).last }
  rescue Timeout::Error
    nil
  ensure
    stop(pid) if pid
  end

  # Ends the process group +pid+ leads, if anything of it is left.
  def stop(pid)
    Process.kill("TERM", -pid)
    sleep 0.5
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  ensure
    begin
      Process.wait(pid, Process::WNOHANG)
    rescue Errno::ECHILD
      nil
    end
  end

  # Runs a command to its end within +limit+, printing its output only if
  # it fails, with none of this process's Bundler or game settings.
  def run(env, *command, what:, limit: 300, chdir: ROOT)
    log = File.join(Dir.tmpdir, "dot_popper-#{what.tr(" ", "-")}-#{Process.pid}.txt")
    clean = ENV.keys.grep(/\A(BUNDLER?_|RUBYOPT\z|RUBYLIB\z|DOT_POPPER_)/).to_h { [it, nil] }
    status = bounded(clean.merge(env), *command, limit:, out: log, chdir:)
    return if status&.success?

    raise Failure, "#{what} #{status ? "failed (#{status.exitstatus})" : "ran past #{limit} s"}:\n#{File.read(log).lines.last(30).join}"
  ensure
    FileUtils.rm_f(log) if log
  end

  # Runs Ruby with Lota from +home+ and none of this process's settings.
  def bare(home, *arguments, dir: ROOT)
    clean = ENV.keys.grep(/\A(BUNDLER?_|RUBYOPT\z|RUBYLIB\z|DOT_POPPER_|GEM_)/).to_h { [it, nil] }
    out, status = Open3.capture2e(clean.merge("GEM_HOME" => home, "GEM_PATH" => home), RbConfig.ruby, *arguments, chdir: dir)
    [out, status.success?]
  end
end

PlayPackagedApp.main(ARGV) if $PROGRAM_NAME == __FILE__
