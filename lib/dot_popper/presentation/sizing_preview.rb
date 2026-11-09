# frozen_string_literal: true

module DotPopper
  module Presentation
    # The title's "Dot size" choice: the share of a radius by which the
    # two sizes may differ and still look alike, the standard icon's
    # radius as a share of its segment's height, and how far the fitted
    # icon may shrink or grow from it.
    class SizingStyle < Data.define(:alike, :icon, :icons); end

    # How the title's "Dot size" choice looks from where the player sits:
    # what dots sized to this screen (DotSizing::SIZED_TO_SCREEN) would do
    # here, next to the standard size. +standard+ and +fitted+ are the two
    # radii on this screen; +style+ (SizingStyle) says how far apart they
    # must be to be worth a choice, and how big the segments' dot icons are.
    class SizingPreview < Data.define(:standard, :fitted, :style)
      # The preview for +screen+, a Field at the standard dot size.
      def self.of(screen, style) = new(standard: screen.radius, fitted: DotSizing::SIZED_TO_SCREEN.fit(screen).radius, style:)

      # How big a fitted dot is next to a standard one.
      def ratio = fitted.to_f / standard

      # What fitting the dots does here: :smaller, :bigger, or :alike when
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
      # standard icon at a fixed share of it, and the fitted one in true
      # proportion to it, kept within +style.icons+ so both stay legible.
      def icon(sizing, height)
        base = height * style.icon
        sizing.sized_to_screen? ? base * ratio.clamp(style.icons) : base
      end
    end
  end
end
