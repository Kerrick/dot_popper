# frozen_string_literal: true

# Fails when this build has no sales channel, which means it was built with
# the fake store (Presentation::Storefront::BUILD_CHANNEL is nil). CI runs it
# on every v1* tag, so a release for a store cannot ship the fake store.
#
#   ruby script/check_build_channel.rb
require_relative "../lib/dot_popper"
require_relative "../lib/dot_popper/presentation"

channel = DotPopper::Presentation::Storefront::BUILD_CHANNEL
if channel.nil?
  warn "BUILD_CHANNEL is nil: this build sells through the fake store. Set it in " \
       "lib/dot_popper/presentation/storefront.rb (ADR-0009) before tagging."
  exit 1
end

puts "BUILD_CHANNEL is #{channel.inspect}"

# A Google Play purchase proves Pro only by the app's own Play key
# (DotPopper::Receipt::PLAY_KEYS), which only the Play Console shows, so a
# store release cannot ship until it is pinned (ADR-0010).
if DotPopper::Receipt::PLAY_KEYS.empty?
  warn "Receipt::PLAY_KEYS is empty: no Google Play purchase would prove Pro. Pin the app's licensing key " \
       "from the Play Console in lib/dot_popper/receipt/pins.rb before tagging."
  exit 1
end
