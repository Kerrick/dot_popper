# frozen_string_literal: true

# From Lota's Android spike (setdef/Lota spike/android/emulator.rb at
# 84c0eda), with --key-after and --expect-order added for Dot Popper's
# Android job (.github/workflows/android.yml).
#
# Runs an app Fledge built on the Android emulator adb sees, and keeps
# what it did: installs the APK, starts its activity with environment
# variables as intent extras (MainActivity's lota.env.NAME), reads what
# the app prints from logcat, under its package name, takes screenshots
# and taps the screen on a schedule counted from the first line that
# matches --ready, and stops when the app says it exited or after
# --timeout seconds. Everything goes in OUT: logcat.txt (all of it),
# app.txt (the app's lines), device.txt, and shot-*.png.
#
#   ruby emulator.rb APK PACKAGE OUT [--env NAME=VALUE]... [--shot SECONDS]...
#     [--tap SECONDS:XFRACTION:YFRACTION]... [--pop] [--ready REGEX] [--timeout SECONDS]
#     [--expect REGEX]... [--pull REGEX] [--key-after SECONDS:KEYCODE:REGEX]...
#     [--expect-order REGEX]... [--until-met]
#
# --pop taps where the app last printed "kit probe: dot at X, Y in WxH"
# (graphics units in a window W by H), until it prints "kit probe: event
# Popped", at most five times. --pull copies, with run-as, every file the
# app names in a line the REGEX's first group captures. It exits 1 unless
# every --expect matches a line of the app's, and the --expect-order
# patterns match lines in the order given. --key-after sends the key
# event KEYCODE once, SECONDS after the first line that matches REGEX;
# each waits for the one before it to be sent, and for the probe to say
# the game's window has the focus, and looks only at the lines that came
# after, so a line the app prints more than once (the
# game hearing it came back, at launch and after the Home screen) is
# matched where the check means it.
# --until-met stops the run as soon as every --expect and --expect-order
# has matched and every key was sent, rather than when the app exits.
# Each run ends by stopping the app, so the next starts it afresh.

require "fileutils"
require "open3"

apk, package, out, *rest = ARGV
abort "usage: emulator.rb APK PACKAGE OUT [options]" unless apk && package && out
envs = []
shots = []
taps = []
expects = []
commands = []
pop = false
ready = /loaded/
timeout = 240.0
pull = nil
keys = []
ordered = []
until_met = false
until rest.empty?
  option = rest.shift
  case option
  when "--env" then envs << rest.shift.split("=", 2)
  when "--shot" then shots << Float(rest.shift)
  when "--tap" then taps << rest.shift.split(":").map { Float(it) }
  when "--shell"
    seconds, command = rest.shift.split(":", 2)
    commands << [Float(seconds), command.gsub("PACKAGE", package).split]
  when "--pop" then pop = true
  when "--ready" then ready = Regexp.new(rest.shift)
  when "--timeout" then timeout = Float(rest.shift)
  when "--expect" then expects << Regexp.new(rest.shift)
  when "--pull" then pull = Regexp.new(rest.shift)
  when "--key-after"
    seconds, code, pattern = rest.shift.split(":", 3)
    keys << { seconds: Float(seconds), code:, pattern: Regexp.new(pattern), at: nil }
  when "--expect-order" then ordered << Regexp.new(rest.shift)
  when "--until-met" then until_met = true
  else abort "emulator.rb: unknown option #{option}"
  end
end
FileUtils.mkdir_p(out)

def adb(*arguments, allow_failure: false)
  output, status = Open3.capture2e("adb", *arguments)
  abort "adb #{arguments.join(' ')} failed:\n#{output}" unless status.success? || allow_failure
  output
end

def say(message)
  puts "#{Time.now.utc.strftime('%H:%M:%S.%L')} #{message}"
  $stdout.flush
end

adb("wait-for-device")
device = {
  "abi" => adb("shell", "getprop", "ro.product.cpu.abi").strip,
  "sdk" => adb("shell", "getprop", "ro.build.version.sdk").strip,
  "release" => adb("shell", "getprop", "ro.build.version.release").strip,
  "page size" => adb("shell", "getconf", "PAGE_SIZE").strip,
  "screen" => adb("shell", "wm", "size").strip,
  "density" => adb("shell", "wm", "density").strip,
  "ro.opengles.version" => adb("shell", "getprop", "ro.opengles.version").strip,
  "ro.hardware.egl" => adb("shell", "getprop", "ro.hardware.egl").strip,
  "ro.hardware.vulkan" => adb("shell", "getprop", "ro.hardware.vulkan").strip,
  "GLES" => adb("shell", "dumpsys", "SurfaceFlinger", allow_failure: true).lines.grep(/GLES|EGL/).first(4).join.strip,
}
File.write(File.join(out, "device.txt"), device.map { |key, value| "#{key}: #{value}" }.join("\n") + "\n")
device.each { |key, value| say "device #{key}: #{value}" }
width, height = device.fetch("screen")[/(\d+)x(\d+)\s*\z/].split("x").map(&:to_i)

# Android's one-time notice for an app that hides the system bars would
# take the first tap (Fledge's ADR 025, section 6).
adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
adb("logcat", "-G", "16M", allow_failure: true)
say adb("install", "-r", "-g", apk).lines.last.to_s.strip
adb("logcat", "-b", "main,system,crash,events", "-c")
# The app's lines as it prints them: a dump of the log each turn of the
# loop lagged by seconds on a busy machine, and a key timed from a line
# then missed the state it was meant for (Back at Game Over arrived on
# Home).
streamed = []
stream_in, stream_out, stream = Open3.popen2("adb", "logcat", "-v", "raw", "-s", "#{package}:V")
stream_in.close
reader = Thread.new { stream_out.each_line { streamed << it.chomp unless it.start_with?("--------- ") } }
extras = envs.flat_map { |name, value| ["--es", "lota.env.#{name}", value] }
say adb("shell", "am", "start", "-W", "-n", "#{package}/org.setdef.fledge.host.MainActivity", *extras).strip

# Whether +patterns+ match lines of +lines+ in their order.
def in_order?(lines, patterns)
  patterns.all? do |pattern|
    index = lines.index { pattern.match?(it) }
    index && (lines = lines.drop(index + 1))
  end
end

# Whether the probe's last word on the window's focus is that it has it.
def focused?(lines)
  lines.reverse.find { it.start_with?("kit probe: focus ") } == "kit probe: focus true"
end

# The window Android says has the input focus.
def focused_window
  adb("shell", "dumpsys", "window", allow_failure: true).lines.grep(/mCurrentFocus/).first.to_s.strip
end

def app_lines(package)
  adb("logcat", "-d", "-v", "raw", "-s", "#{package}:V").lines.map(&:chomp).reject { it.start_with?("--------- ") }
end

started = Time.now
seen = 0
origin = nil
pop_taps = 0
probe_failed = false
last_tap = nil
pending_shots = shots.sort
pending_taps = taps.sort_by(&:first)
commands.sort_by!(&:first)
shot_number = 0
loop do
  lines = streamed.dup
  lines.drop(seen).each { |line| say "app: #{line}" }
  seen = lines.size
  origin ||= Time.now if lines.any? { ready.match?(it) }
  elapsed = origin && (Time.now - origin)
  while elapsed && pending_shots.first && elapsed >= pending_shots.first
    pending_shots.shift
    shot_number += 1
    path = File.join(out, "shot-#{shot_number}.png")
    File.binwrite(path, Open3.capture2("adb", "exec-out", "screencap", "-p", binmode: true).first)
    say "screenshot #{path} at #{elapsed.round(1)} s, #{File.size(path)} bytes"
  end
  while elapsed && pending_taps.first && elapsed >= pending_taps.first.first
    _, x, y = pending_taps.shift
    px = (x * width).round
    py = (y * height).round
    adb("shell", "input", "tap", px.to_s, py.to_s)
    say "tapped #{px}, #{py} at #{elapsed.round(1)} s"
  end
  while elapsed && commands.first && elapsed >= commands.first.first
    _, command = commands.shift
    say "adb shell #{command.join(' ')} at #{elapsed.round(1)} s: #{adb('shell', *command, allow_failure: true).strip}"
  end
  keys.each_with_index do |key, index|
    next if key[:sent]
    break unless index.zero? || keys[index - 1][:sent]

    from = index.zero? ? 0 : keys[index - 1][:after]
    key[:at] ||= (Time.now + key[:seconds] if lines.drop(from).any? { key[:pattern].match?(it) })
    break unless key[:at] && Time.now >= key[:at]
    # A key goes to the window that has the input focus: wait until the
    # probe says the game's window has it.
    break unless focused?(lines)

    key[:sent] = true
    key[:after] = lines.size
    adb("shell", "input", "keyevent", key[:code])
    say "sent #{key[:code]}, #{key[:seconds]} s after a line matched #{key[:pattern].source}; #{focused_window}"
  end
  if pop && pop_taps < 5 && lines.none? { it.include?("kit probe: event Popped") }
    probe = lines.reverse.find { it.include?("kit probe: dot at") }
    match = probe&.match(/dot at ([\d.]+), ([\d.]+) in ([\d.]+)x([\d.]+)/)
    if match && probe != last_tap
      last_tap = probe
      x, y, w, h = match.captures.map { Float(it) }
      px = (x / w * width).round
      py = (y / h * height).round
      adb("shell", "input", "tap", px.to_s, py.to_s)
      pop_taps += 1
      say "tapped the dot at #{x.round}, #{y.round} of #{w.round}x#{h.round}: #{px}, #{py} on the screen"
    end
  end
  probe_error = lines.find { it.include?("kit probe: error") }
  if probe_error
    say "the kit probe failed: #{probe_error}"
    probe_failed = true
    break
  end
  break if lines.any? { it.include?("exited with status") }
  if until_met && keys.all? { it[:sent] } && expects.all? { |pattern| lines.any? { pattern.match?(it) } } && in_order?(lines, ordered)
    say "every expectation met"
    break
  end

  if Time.now - started > 20 && adb("shell", "pidof", package, allow_failure: true).strip.empty?
    say "the app's process is gone"
    break
  end
  if Time.now - started > timeout
    say "timed out after #{timeout} s"
    break
  end
  sleep 0.1
end

Process.kill("TERM", stream.pid) rescue nil # rubocop:disable Style/RescueModifier
reader.join(2)
File.write(File.join(out, "logcat.txt"), adb("logcat", "-d", "-b", "main,system,crash,events", "-v", "threadtime"))
adb("shell", "am", "force-stop", package, allow_failure: true)
lines = app_lines(package)
File.write(File.join(out, "app.txt"), lines.join("\n") + "\n")
if pull
  lines.filter_map { it[pull, 1] }.uniq.each do |path|
    copy = File.join(out, "game-#{File.basename(path)}")
    data, status = Open3.capture2("adb", "exec-out", "run-as", package, "cat", path, binmode: true)
    if status.success?
      File.binwrite(copy, data)
      say "pulled #{path}: #{data.bytesize} bytes"
    else
      say "could not pull #{path}"
    end
  end
end
crashes = File.read(File.join(out, "logcat.txt")).lines.grep(/FATAL|Fatal signal|AndroidRuntime|DEBUG\s*:|libc\s*:|SDL\s*: activity finished|wm_relaunch\w*: .*#{Regexp.escape(package)}/)
say "crash lines:\n#{crashes.first(80).join}" unless crashes.empty?
missing = expects.reject { |pattern| lines.any? { pattern.match?(it) } }
missing.each { say "missing: #{it.source}" }
rest_of_lines = lines
out_of_order = ordered.find do |pattern|
  index = rest_of_lines.index { pattern.match?(it) }
  index.nil?.tap { rest_of_lines = rest_of_lines.drop(index.to_i + 1) }
end
say "missing, in order: #{out_of_order.source}" if out_of_order
unsent = keys.reject { it[:sent] }
unsent.each { say "never sent #{it[:code]}: no line matched #{it[:pattern].source}" }
passed = !probe_failed && missing.empty? && out_of_order.nil? && unsent.empty?
unless passed
  say "the focused window: #{focused_window}"
  life = File.read(File.join(out, "logcat.txt")).lines.grep(/#{Regexp.escape(package)}/)
              .grep(/am_proc_start|am_proc_died|am_kill|am_crash|am_anr|am_wtf|wm_on_\w+_called|wm_finish_activity|wm_relaunch|ActivityTaskManager|ActivityManager/)
  say "the app's life, from the log:\n#{life.last(40).join}"
end
exit(passed ? 0 : 1)
