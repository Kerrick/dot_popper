# frozen_string_literal: true

# Checks an app that was built, not this repository: loads the game's code
# from the unpacked app in FOLDER (its game/dot_popper folder, as
# `lota fuse` lays it out) and fails unless that code is a build for
# CHANNEL at VERSION, which trusts setdef's real keys and no test key
# (ADR-0010). It asks nothing of the internet. Only CHANNEL's own needs
# are checked: a website build needs no Play key or store identifier.
# The Package workflow runs it on every build for sale it makes, and
# Lota must be installed (the shell's code needs it to load).
#
#   ruby script/check_build.rb website 1.0.0 "unpacked/Dot Popper"
require "yaml"

channel, version, folder = ARGV
abort "usage: ruby script/check_build.rb CHANNEL VERSION FOLDER" unless channel && version && folder && File.directory?(folder)

games = Dir.glob(File.join(File.expand_path(folder), "**", "game", "dot_popper", "lib", "dot_popper", "build.rb"))
           .map { File.expand_path("../../..", it) }
abort "#{folder} holds #{games.size} copies of the game; expected one" unless games.size == 1
game = games.first
puts "Checking the game in #{game}"

$LOAD_PATH.unshift(File.join(game, "lib"))
require "dot_popper"
require "lota"
require "dot_popper/shell"

failures = []
check = lambda do |what, &passes|
  ok = begin
    passes.call
  rescue StandardError => e
    warn "  (#{e.class}: #{e.message})"
    false
  end
  puts "#{ok ? "ok  " : "FAIL"} #{what}"
  failures << what unless ok
end

# The game's code is lib/dot_popper.rb and what is under lib/dot_popper/;
# another folder named dot_popper (one holding Ruby itself, say) is not.
ours = $LOADED_FEATURES.grep(%r{/lib/dot_popper(/|\.rb\z)})
check.call("every file of the game's code loaded is the app's own") { ours.any? && ours.all? { it.start_with?(game) } }

build = DotPopper::Build
c = DotPopper::Continuity
check.call("#{channel.inspect} is a channel the game names (#{build::CHANNEL_NAMES.join(", ")})") { build::CHANNEL_NAMES.include?(channel) }
check.call("the app was built for #{channel.inspect} (Build::CHANNEL is #{build::CHANNEL.inspect})") { build::CHANNEL == channel }

root = DotPopper::Composition::Root
pins = root.trusted_pins(build::CHANNEL)
check.call("it trusts setdef's own keys (Continuity::SETDEF_PINS)") { pins.equal?(c::PINNED) && c::PINNED == c::SETDEF_PINS && c.live?(pins) }
check.call("it trusts no test key") do
  (pins.roots & c::TEST_PINS.roots).empty? && (pins.license_keys & c::TEST_PINS.license_keys).empty?
end

# Each "grants nothing" below is shown against its control: the same
# proof does grant in a test build, so a Ruby that verifies nothing
# cannot pass them.
seeds = [c::TestKeys::ROOT, c::TestKeys::LICENSE, c::TestKeys::ONLINE]
check.call("this Ruby verifies Ed25519, and a key signed by the test key unlocks a test build") do
  c::Ed25519.available? && c::LicenseKey.issue(c::TestKeys::LICENSE).valid?(c::TEST_PINS)
end
check.call("no license key signed by a test key unlocks it") { seeds.none? { c::LicenseKey.issue(it).valid?(pins) } }
check.call("it takes no proof certified by the test root") do
  c::Certificate.verified(c::TestKeys.online_certificate, roots: c::TEST_PINS.roots, purpose: c::Certificate::PROOF) &&
    c::Certificate.verified(c::TestKeys.online_certificate, roots: pins.roots, purpose: c::Certificate::PROOF).nil?
end
check.call("the fake store's receipt proves nothing in it") do
  receipt = DotPopper::Receipt.issue
  DotPopper::Entitlement.new(trust: DotPopper::Receipt::TEST).prove(receipt) &&
    !DotPopper::Entitlement.new(trust: root.trusted_receipts(build::CHANNEL)).prove(receipt)
end
check.call("no setting grants Pro or changes the server in it") do
  env = build.settings({ "DOT_POPPER_PRO" => "1", "DOT_POPPER_SERVER" => "http://localhost:1" })
  !DotPopper::Entitlement.forced?(env) && DotPopper::Network::Settings.server_url(env) == DotPopper::Network::Settings::SERVER_URL
end

shipped = YAML.load_file(File.join(game, "fledge.yml")).fetch("version").to_s
check.call("its version is #{version} (the app's fledge.yml says #{shipped})") { shipped == version }

# What only some channels need.
if channel == build::GOOGLE_PLAY
  check.call("it pins the app's Play key (Receipt::PLAY_KEYS)") { DotPopper::Receipt::PLAY_KEYS.any? }
end
if channel == build::WEBSITE
  check.call("it keeps and checks a license key") { build.license_keys?(build::CHANNEL) }
end

if failures.any?
  warn "#{failures.size} check#{"s" unless failures.size == 1} failed: this app is not a #{channel} build of #{version}."
  exit 1
end
puts "This app is a #{channel} build of #{version}."
