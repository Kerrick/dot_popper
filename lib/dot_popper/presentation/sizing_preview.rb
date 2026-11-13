# frozen_string_literal: true

module DotPopper
  module Presentation
    # Settings' "Dot size" choice: the share of a radius by which the
    # two sizes may differ and still look alike, the bigger or smaller
    # size's icon's radius as a share of its segment's height, and how far
    # Standard's icon may shrink or grow from it.
    class SizingStyle < Data.define(:alike, :icon, :icons); end

    # How Settings' "Dot size" choice looks from where the player sits:
    # what standard dots (DotSizing::STANDARD), worked out from this
    # screen, do here next to the bigger or smaller size.
    # +bigger_or_smaller+ and +standard+ are the two radii on this screen;
    # +style+ (SizingStyle) says how far apart they must be to be worth a
    # choice, and how big the segments' dot icons are.
    class SizingPreview < Data.define(:bigger_or_smaller, :standard, :style)
      # The preview for +screen+, a Field at the bigger or smaller dot size.
      def self.of(screen, style)
        new(bigger_or_smaller: screen.radius, standard: DotSizing::STANDARD.fit(screen).radius, style:)
      end

      # How big a standard dot is next to one of the bigger or smaller size.
      def ratio = standard.to_f / bigger_or_smaller

      # What standard dots do here, next to the bigger or smaller size:
      # :smaller, :bigger, or :alike when the two are within +style.alike+
      # of each other.
      def effect
        if ratio < 1 - style.alike then :smaller
        elsif ratio > 1 + style.alike then :bigger
        else :alike
        end
      end

      # Whether the two sizes look alike here.
      def alike? = effect == :alike

      # Whether Settings offers the choice to a player whose saved size is
      # +chosen+: where it changes anything they would see, and always
      # while the bigger or smaller size is saved, so no player is left in a
      # state no control shows or leaves.
      def offered?(chosen = DotSizing::STANDARD) = !alike? || !chosen.standard?

      # The radius of +sizing+'s icon on a segment +height+ tall: the
      # bigger or smaller size's icon at a set share of it, and Standard's
      # in true proportion to it, kept within +style.icons+ so both stay
      # legible.
      def icon(sizing, height)
        base = height * style.icon
        sizing.standard? ? base * ratio.clamp(style.icons) : base
      end
    end
  end
end
