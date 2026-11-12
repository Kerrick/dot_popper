# frozen_string_literal: true

module DotPopper
  # What kind of build this is, fixed when the app is built and never by
  # anything a player can set at run time: not an environment variable, a
  # file, or an argument. A test build (no channel) is a playtest kit: it
  # trusts the test keys, sells through fakes, and obeys every developer
  # setting. A store build (a channel) trusts only setdef's keys, sells
  # through its channel's store, and ignores each developer setting that
  # could grant Pro, change the server, or skip the free-game limit
  # (ADR-0010).
  module Build
    # The channel this build is sold through, one of CHANNEL_NAMES, or nil
    # for a test build. A build for sale MUST set it, and its release
    # checks that the app it built did (script/check_build.rb).
    CHANNEL = nil

    # Every channel a build can be sold through: the app stores', and
    # setdef's website, for copies no store controls. This is the one list
    # of their names, which the scripts take from here.
    APP_STORE = "app-store"
    MAC_APP_STORE = "mac-app-store"
    GOOGLE_PLAY = "google-play"
    MICROSOFT_STORE = "microsoft-store"
    WEBSITE = "website"

    PREFIX = "DOT_POPPER_"

    # The developer settings a store build still obeys, since none of them
    # touches a purchase, Pro, the server, the date or the free games: how
    # the window and graphics start, calm and diagnostic aids, a repeatable
    # seed, the tutorial, and the bot and screenshots (an automated run of
    # a store build still meters its free games and sells through its
    # channel). Every other DOT_POPPER_* setting, known or not yet written,
    # is inert in a store build.
    HARMLESS = %w[
      AUTOPLAY CALM DIAGNOSTIC_COLORS FAKE_DRAG FAKE_GAMEPAD FAKE_TILT FULLSCREEN
      NO_SHADERS NO_SPLASH NO_TUTORIAL NO_VULKAN PERF QUIT_AFTER RENDERERS SEED
      SHOTS TUTORIAL WINDOW
    ].map { "#{PREFIX}#{it}" }.freeze

    def self.store?(channel = CHANNEL) = !channel.nil?

    # The channels of the app stores, whose copies never accept, keep,
    # verify or send a website license key (Apple 3.1.1; Google's billing
    # rules). Every other channel, WEBSITE and a test build, may.
    STORES = [APP_STORE, MAC_APP_STORE, GOOGLE_PLAY, MICROSOFT_STORE].freeze
    CHANNEL_NAMES = [*STORES, WEBSITE].freeze

    def self.license_keys?(channel = CHANNEL) = !STORES.include?(channel)

    # +env+ as this build lets it be read: untouched in a test build, and
    # in a store build without the developer settings that affect purchases,
    # Pro or the server.
    def self.settings(env = ENV, channel: CHANNEL)
      return env unless store?(channel)

      env.to_h.reject { |name, _| name.start_with?(PREFIX) && !HARMLESS.include?(name) }
    end
  end
end
