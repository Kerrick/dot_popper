# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

# Lota is not on RubyGems.org. Its precompiled gems for each platform we
# build on live in vendor/cache, downloaded from its GitHub release and
# checked against the release's SHA256SUMS.
gem "lota", "0.1.2"

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end
