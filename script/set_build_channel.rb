# frozen_string_literal: true

# Makes this working copy a build for sale: sets DotPopper::Build::CHANNEL
# in lib/dot_popper/build.rb to CHANNEL, before `lota fuse` builds the app,
# so the channel is fixed in the app and nothing a player sets can change
# it (ADR-0010), and sets Build::PARTS to the parts that channel carries
# (none of the test build's), so the app loads no other channel's code.
# CI runs it in a channel's own jobs only; the repository's own file stays
# a test build. Refuses a name not in Build::CHANNEL_NAMES.
# script/check_build.rb then checks the app that was built.
#
#   ruby script/set_build_channel.rb website
require_relative "../lib/dot_popper/build"

module BuildChannel
  KNOWN = DotPopper::Build::CHANNEL_NAMES
  CHANNEL_LINE = /^    CHANNEL = nil$/
  PARTS_LINE = /^    PARTS = %w\[[a-z_ ]*\]\.freeze$/
  # The parts (lib/dot_popper/PART) each channel's build carries.
  PARTS = KNOWN.to_h { [it, []] }.freeze

  # +source+, a test build's build.rb, as +channel+'s; raises ArgumentError
  # for a channel the game doesn't name or a file that isn't a test build's.
  def self.stamp(source, channel)
    raise ArgumentError, "#{channel.inspect} is not one of #{KNOWN.join(", ")}" unless KNOWN.include?(channel)
    raise ArgumentError, "build.rb has no `CHANNEL = nil` line to set" unless source.match?(CHANNEL_LINE)
    raise ArgumentError, "build.rb has no `PARTS = %w[...]` line to set" unless source.match?(PARTS_LINE)

    source.sub(CHANNEL_LINE, "    CHANNEL = #{channel.inspect}").sub(PARTS_LINE, "    PARTS = %w[#{PARTS.fetch(channel).join(" ")}].freeze")
  end
end

if $PROGRAM_NAME == __FILE__
  file = File.expand_path("../lib/dot_popper/build.rb", __dir__)
  channel = ARGV.fetch(0, "")
  begin
    File.write(file, BuildChannel.stamp(File.read(file), channel))
  rescue ArgumentError => e
    abort "#{e.message}\nusage: ruby script/set_build_channel.rb CHANNEL (one of #{BuildChannel::KNOWN.join(", ")})"
  end
  puts "Build::CHANNEL is #{channel.inspect}, and Build::PARTS #{BuildChannel::PARTS.fetch(channel).inspect}"
end
