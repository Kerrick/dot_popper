# frozen_string_literal: true

require_relative "../../dot_popper"

module DotPopper
  module Privacy
    # Declared and in the privacy manifest, but not yet in the game's code:
    # each a Network::Request, declared here until it is built and then in
    # the part that makes it. test/privacy/requests_test.rb fails as soon
    # as one is built, so it cannot go out unplayed.
    UNBUILT_REQUESTS = {}.freeze

    # The parts of the game that make requests, each declaring its own as
    # REQUESTS where it lives, in the order doc/privacy.json lists them.
    PARTS = [Groups, ThemeReleases, Continuity::SetdefServer, Continuity::Connectivity].freeze

    # Every request the game makes: each part's, then those not yet built.
    # A kind declared twice is refused.
    REQUESTS = [*PARTS.map { it::REQUESTS }, UNBUILT_REQUESTS].reduce do |all, part|
      all.merge(part) { |kind| raise ArgumentError, "#{kind} is declared twice" }
    end.freeze

    # What the game reaches its server for, in this build.
    def self.features_built = REQUESTS.values.reject { UNBUILT_REQUESTS.key?(it.kind) }.map(&:feature).uniq
  end
end
