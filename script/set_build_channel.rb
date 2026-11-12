# frozen_string_literal: true

# Makes this working copy a store build: sets DotPopper::Build::CHANNEL in
# lib/dot_popper/build.rb to CHANNEL, before `lota fuse` builds the app, so
# the channel is fixed in the app and nothing a player sets can change it
# (ADR-0010). CI runs
# it in a store build's job only; the repository's own file stays nil, a
# test build. Refuses a channel no store build is made for.
#
#   ruby script/set_build_channel.rb mac-app-store
require_relative "../lib/dot_popper"
require_relative "../lib/dot_popper/presentation"

storefront = DotPopper::Presentation::Storefront
KNOWN = [*storefront::HELPER_CHANNELS.keys, storefront::WEBSITE].freeze
FILE = File.expand_path("../lib/dot_popper/build.rb", __dir__)
LINE = /^    CHANNEL = nil$/

channel = ARGV.fetch(0, "")
abort "usage: ruby script/set_build_channel.rb CHANNEL (one of #{KNOWN.join(", ")})" unless KNOWN.include?(channel)

source = File.read(FILE)
abort "#{FILE} has no `CHANNEL = nil` line to set" unless source.match?(LINE)

File.write(FILE, source.sub(LINE, "    CHANNEL = #{channel.inspect}"))
puts "Build::CHANNEL is #{channel.inspect}"
