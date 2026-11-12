# frozen_string_literal: true

# Fails when an identifier that CHANNEL's build needs, and that only that
# store's account shows, is missing from the repository's variables or is
# still a stand-in: for the Microsoft Store its package identity, and for
# Apple's stores the Apple Developer Team ID the build signs with
# (doc/publishing.md). A release for CHANNEL runs it with those variables
# in the environment, so it cannot ship a store build with a stand-in. A
# channel that needs none, such as the website's, passes.
#
#   MSIX_IDENTITY_NAME=... MSIX_PUBLISHER=... ruby script/check_store_identifiers.rb microsoft-store
require_relative "../lib/dot_popper/build"

build = DotPopper::Build
IDENTIFIERS = {
  "MSIX_IDENTITY_NAME" => ["the Microsoft Store's Package/Identity/Name, from Partner Center's Product identity page",
                           /\A[A-Za-z0-9.-]{3,50}\z/, "setdef.DotPopper"],
  "MSIX_PUBLISHER" => ["the Microsoft Store's Package/Identity/Publisher (CN=...), from the same page",
                       /\ACN=\S/, "CN=Dot Popper test"],
  "APPLE_TEAM_ID" => ["the Apple Developer Team ID (ten letters and digits), from developer.apple.com, Membership",
                      /\A[A-Z0-9]{10}\z/, nil]
}.freeze
NEEDED = {
  build::MICROSOFT_STORE => %w[MSIX_IDENTITY_NAME MSIX_PUBLISHER],
  build::MAC_APP_STORE => %w[APPLE_TEAM_ID],
  build::APP_STORE => %w[APPLE_TEAM_ID]
}.freeze

channel = ARGV.fetch(0, "")
unless build::CHANNEL_NAMES.include?(channel)
  abort "usage: ruby script/check_store_identifiers.rb CHANNEL (one of #{build::CHANNEL_NAMES.join(", ")})"
end

missing = NEEDED.fetch(channel, []).filter_map do |name|
  what, form, placeholder = IDENTIFIERS.fetch(name)
  value = ENV.fetch(name, "").strip
  "#{name}: #{what}" if value.empty? || value == placeholder || !form.match?(value)
end

if missing.any?
  warn "#{channel} needs these store identifiers, which are missing or still stand-ins. Set each with `gh variable set NAME`:"
  missing.each { warn "  #{it}" }
  exit 1
end

puts "Every store identifier #{channel} needs is set"
