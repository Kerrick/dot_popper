# frozen_string_literal: true

module DotPopper
  # How big a dot is on this device: its radius in Lota's graphics units,
  # worked out once when the game starts.
  #
  # The aim is a physical size: about 8 mm of radius under a finger, and
  # 50 logical pixels under a mouse, where a desktop's own display scaling
  # already sets how big a pixel looks. With +t.highdpi+ on, Lota's
  # graphics units are those logical pixels on a desktop, and points (iOS)
  # or density-independent pixels (Android) on a phone or tablet. Neither
  # Lota nor LÖVE reports a screen's physical density, so on a touch
  # system the radius falls back to 50 units as well: 50 iOS points is
  # 7.9 to 9.6 mm across today's iPhones and iPads, and 50 dp is 7.9 mm by
  # Android's definition (160 dp to the inch).
  class DotSize < Data.define(:radius, :reason)
    TOUCH_SYSTEMS = %w[iOS Android].freeze

    # +os+ is what Lota::System.os answers, such as "OS X", "Windows",
    # "Linux", "iOS", or "Android".
    def self.for(os)
      if TOUCH_SYSTEMS.include?(os)
        new(radius: Rules::RADIUS, reason: "#{Rules::RADIUS} #{os == "iOS" ? "points" : "dp"}, about 8 mm")
      else
        new(radius: Rules::RADIUS, reason: "#{Rules::RADIUS} logical pixels")
      end
    end

    def field(width, height) = Field.new(width, height, radius)
  end
end
