# frozen_string_literal: true

require "date"
require_relative "../../dot_popper"

module DotPopper
  # Where the game is put together (Root), apart from Lota: what it is
  # built from on each platform and in each kind of build is decided here,
  # in plain Ruby that a test runs without a window, and the shell only
  # hands in what needs the engine (Shell::Engine).
  module Composition
    # The developer settings (DOT_POPPER_*) this run obeys, read from the
    # environment as the build allows (Build.settings): every one in a test
    # build, and in a store build only Build::HARMLESS's. +channel+ is the
    # build's (Build::CHANNEL), and not anything set at run time.
    class DeveloperSettings
      attr_reader :channel, :env

      def initialize(env = ENV, channel: Build::CHANNEL)
        @channel = channel
        @env = Build.settings(env, channel:)
      end

      # Whether this is a store build (a channel), rather than a test build.
      def store_build? = Build.store?(channel)

      # Whether +name+ is set to 1.
      def flag?(name) = env[name] == "1"

      def fetch(name, default = "") = env.fetch(name, default)
      def [](name) = env[name]

      # Whether this run is automated (Automation), and so stays off the
      # internet.
      def automated? = Automation.on?(env)

      # DOT_POPPER_CALM=1: reduced motion.
      def calm? = flag?("DOT_POPPER_CALM")

      # DOT_POPPER_FAKE_GAMEPAD=1: plays as if a gamepad were in hand.
      def fake_gamepad? = flag?("DOT_POPPER_FAKE_GAMEPAD")

      # DOT_POPPER_SEED=42: the dots' randomness, made repeatable; nil
      # without it.
      def seed = Integer(fetch("DOT_POPPER_SEED"), exception: false)

      # The player's local date, or DOT_POPPER_TODAY's, to try another
      # day's goal or a streak, as a callable.
      def today
        pretend = Date.iso8601(fetch("DOT_POPPER_TODAY"))
        -> { pretend }
      rescue Date::Error
        -> { Date.today }
      end

      # The moment the server's dates are told from, in UTC: now, or
      # midnight UTC of DOT_POPPER_TODAY's day, as a callable.
      def utc_clock
        pretend = Date.iso8601(fetch("DOT_POPPER_TODAY"))
        -> { Time.utc(pretend.year, pretend.month, pretend.day) }
      rescue Date::Error
        -> { Time.now.utc }
      end

      # DOT_POPPER_WINDOW=400x850: a window of that size, no smaller than
      # +smallest+, for checking a narrow screen; nil without it.
      def window_size(smallest)
        width, height = fetch("DOT_POPPER_WINDOW").split("x", 2).map { Integer(it, exception: false) }
        [[width, smallest[0]].max, [height, smallest[1]].max] if width && height
      end
    end

    # The old name, until no commit uses it.
    Settings = DeveloperSettings
  end
end
