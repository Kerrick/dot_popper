# frozen_string_literal: true

module DotPopper
  module Presentation
    # DotPopper::ThemeReleases, for those still made with a +theme_keeper+
    # (ThemeKeeper): it tells the keeper's rules what the server released.
    class ThemeFeed < ThemeReleases
      def initialize(worker:, theme_keeper:, store:, clock: -> { Time.now }) = super(worker:, themes: theme_keeper.rules, store:, clock:)
    end
  end
end
