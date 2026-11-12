# frozen_string_literal: true

# What a pushed tag releases, printed as one word, which the Package, Kits
# and Android workflows read before they attach anything to a release:
#
# - website: Dot Popper for sale. The release's downloads are the
#   website builds alone (Build::WEBSITE), which sell Pro through the
#   checkout; no test build or playtest kit is attached, since their fake
#   checkout gives Pro away. A tag with a suffix (v1.0.0-rc.1) makes a
#   prerelease of the same.
# - playtest: a playtest release, a prerelease of the test builds and
#   the kits.
# - none: nothing is released.
#
#   ruby script/release_kind.rb v1.0.0   # => website
#
# WEBSITE_TAGS is the one place that says which tags sell Pro. Check it
# before tagging. A website tag is never also a playtest one.
WEBSITE_TAGS = /\Av[1-9]\d*\.\d+\.\d+(-[0-9A-Za-z.]+)?\z/
PLAYTEST_TAGS = /\Av0\./

def release_kind(tag)
  return "website" if WEBSITE_TAGS.match?(tag)
  return "playtest" if PLAYTEST_TAGS.match?(tag)

  "none"
end

puts release_kind(ARGV.fetch(0, "")) if $PROGRAM_NAME == __FILE__
