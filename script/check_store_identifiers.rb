# frozen_string_literal: true

# Fails when a store's identifier, which only that store's account shows,
# is missing from the repository's variables: the Microsoft Store's
# package identity, and the Apple Developer Team ID that the Mac App
# Store's build signs and sandboxes with (doc/publishing.md). CI runs it on
# every v1* tag (release-channel.yml), with those variables in the
# environment, so a release cannot ship a store build with a stand-in.
#
#   MSIX_IDENTITY_NAME=... MSIX_PUBLISHER=... APPLE_TEAM_ID=... ruby script/check_store_identifiers.rb

NEEDED = {
  "MSIX_IDENTITY_NAME" => ["the Microsoft Store's Package/Identity/Name, from Partner Center's Product identity page",
                           /\A[A-Za-z0-9.-]{3,50}\z/, "setdef.DotPopper"],
  "MSIX_PUBLISHER" => ["the Microsoft Store's Package/Identity/Publisher (CN=...), from the same page",
                       /\ACN=\S/, "CN=Dot Popper test"],
  "APPLE_TEAM_ID" => ["the Apple Developer Team ID (ten letters and digits), from developer.apple.com, Membership",
                      /\A[A-Z0-9]{10}\z/, nil]
}.freeze

missing = NEEDED.filter_map do |name, (what, form, placeholder)|
  value = ENV.fetch(name, "").strip
  "#{name}: #{what}" if value.empty? || value == placeholder || !form.match?(value)
end

if missing.any?
  warn "These store identifiers are missing or still stand-ins. Set each with `gh variable set NAME`:"
  missing.each { warn "  #{it}" }
  exit 1
end

puts "Every store identifier is set"
