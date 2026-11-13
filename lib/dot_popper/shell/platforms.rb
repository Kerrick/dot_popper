# frozen_string_literal: true

module DotPopper
  module Shell
    # The game's Platform for each system, by the name Lota::System.os
    # (LÖVE's love.system.getOS) gives it. This is the one place a system's
    # name is compared; everything else asks the Platform. A system not
    # named here plays as a computer.
    module Platforms
      BY_NAME = {
        "OS X" => Platform::COMPUTER.with(command_key: true, own_store: Build::MAC_APP_STORE),
        "Windows" => Platform::COMPUTER.with(own_store: Build::MICROSOFT_STORE),
        "Linux" => Platform::COMPUTER,
        # iOS apps are left by the system, never by the app; LÖVE's buzz
        # there ignores its length (Haptics); and a copy sells through the
        # App Store alone (Apple 3.1.1).
        "iOS" => Platform::PHONE.with(quits_itself: false, website_sales: false),
        "Android" => Platform::PHONE.with(buzzes: true)
      }.freeze

      # What one of Lota's graphics units is called on each system, with
      # t.highdpi on, for the line the game prints about a dot's size: a
      # point on iOS, a density-independent pixel on Android, and a
      # logical pixel on a computer.
      UNITS = { "iOS" => "points", "Android" => "dp" }.freeze
      COMPUTER_UNIT = "logical pixels"

      # The Platform for +name+, as Lota::System.os answers it.
      def self.for(name) = BY_NAME.fetch(name, Platform::COMPUTER)

      # What a graphics unit is called on the system Lota calls +name+.
      def self.unit(name) = UNITS.fetch(name, COMPUTER_UNIT)
    end
  end
end
