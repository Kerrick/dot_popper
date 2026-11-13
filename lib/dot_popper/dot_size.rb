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
    # The reason is frozen, as every part of a value is, so a DotSize can
    # be shared between Ractors.
    def initialize(radius:, reason:) = super(radius:, reason: -reason)

    # The usual size on +platform+ (Platform): under a finger, about 8 mm.
    # +unit+ is what the engine calls a graphics unit there, for the reason.
    def self.for(platform, unit:)
      reason = "#{Rules::RADIUS} #{unit}"
      new(radius: Rules::RADIUS, reason: platform.touch? ? "#{reason}, about 8 mm" : reason)
    end

    # The size of a dot "sized to your screen" (DotSizing) on a window
    # +width+ by +height+ units: the radius that makes the field
    # Rules::FITTED_AREA square radii, within the limits the rules set.
    def self.fitted(width, height)
      largest = [[width.to_f, height.to_f].min * Rules::LARGEST_FITTED_SHARE, Rules::SMALLEST_FITTED_RADIUS].max
      radius = Math.sqrt(width.to_f * height.to_f / Rules::FITTED_AREA).clamp(Rules::SMALLEST_FITTED_RADIUS.to_f, largest)
      new(radius:, reason: format("%.1f units, sized to the screen", radius))
    end

    def field(width, height) = Field.new(width, height, radius)
  end
end
