# frozen_string_literal: true

module DotPopper
  module Presentation
    # Settings' "Dot size" choice: the share of a radius by which the
    # two sizes may differ and still look alike, the fixed size's icon's
    # radius as a share of its segment's height, and how far Standard's
    # icon may shrink or grow from it.
    class SizingStyle < Data.define(:alike, :icon, :icons); end

    # How Settings' "Dot size" choice looks from where the player sits:
    # what standard dots (DotSizing::SIZED_TO_SCREEN), worked out from this
    # screen, do here next to the fixed size. +fixed+ and +fitted+ are the
    # two radii on this screen; +style+ (SizingStyle) says how far apart they
    # must be to be worth a choice, and how big the segments' dot icons are.
    class SizingPreview < Data.define(:fixed, :fitted, :style)
      # The preview for +screen+, a Field at the fixed dot size.
      def self.of(screen, style) = new(fixed: screen.radius, fitted: DotSizing::SIZED_TO_SCREEN.fit(screen).radius, style:)

      # How big a standard dot is next to one of the fixed size.
      def ratio = fitted.to_f / fixed

      # What standard dots do here, next to the fixed size: :smaller, :bigger, or :alike when
      # the two are within +style.alike+ of each other.
      def effect
        if ratio < 1 - style.alike then :smaller
        elsif ratio > 1 + style.alike then :bigger
        else :alike
        end
      end

      # Whether the choice changes anything a player would see here.
      def offered? = effect != :alike

      # The radius of +sizing+'s icon on a segment +height+ tall: the
      # fixed size's icon at a set share of it, and Standard's in true
      # proportion to it, kept within +style.icons+ so both stay legible.
      def icon(sizing, height)
        base = height * style.icon
        sizing.sized_to_screen? ? base * ratio.clamp(style.icons) : base
      end
    end
  end
end
