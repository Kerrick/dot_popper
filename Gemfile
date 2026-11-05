# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

# Lota is not on RubyGems.org. Its precompiled gems for each platform we
# build on live in vendor/cache, downloaded from its GitHub release and
# checked against the release's SHA256SUMS.
gem "lota", ">= 0.1.3", "< 0.2"

# Fledge packages the game for people who don't have Ruby (PACKAGING.md).
# It is pinned to v0.5.0, the first release that accepts the System32
# DLLs Lota's Windows gem imports. In the development group, so fledge
# build leaves it out of the app.
group :development do
  gem "fledge", git: "https://github.com/setdef/Fledge", tag: "v0.5.0"

  # Steep checks the rules core against its RBS signatures in sig/
  # (bundle exec rake steep). Only the default rake task needs it;
  # rake test runs without it.
  gem "steep", "~> 2.1", require: false
end

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end
