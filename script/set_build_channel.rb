# frozen_string_literal: true

# Makes this working copy a build for sale: sets DotPopper::Build::CHANNEL
# in lib/dot_popper/build.rb to CHANNEL, before `lota fuse` builds the app,
# so the channel is fixed in the app and nothing a player sets can change
# it (ADR-0010). CI runs it in a channel's own jobs only; the repository's
# own file stays nil, a test build. Refuses a name not in
# Build::CHANNEL_NAMES. script/check_build.rb then checks the app that was
# built.
#
#   ruby script/set_build_channel.rb website
require_relative "../lib/dot_popper/build"

KNOWN = DotPopper::Build::CHANNEL_NAMES
FILE = File.expand_path("../lib/dot_popper/build.rb", __dir__)
LINE = /^    CHANNEL = nil$/

channel = ARGV.fetch(0, "")
abort "usage: ruby script/set_build_channel.rb CHANNEL (one of #{KNOWN.join(", ")})" unless KNOWN.include?(channel)

source = File.read(FILE)
abort "#{FILE} has no `CHANNEL = nil` line to set" unless source.match?(LINE)

File.write(FILE, source.sub(LINE, "    CHANNEL = #{channel.inspect}"))
puts "Build::CHANNEL is #{channel.inspect}"
