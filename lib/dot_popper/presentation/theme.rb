# frozen_string_literal: true

module DotPopper
  module Presentation
    # The sky of a theme's night, as the scene shader takes it.
    class ThemeSky < Data.define(:top, :mid, :bottom, :glow, :glow_at, :glow_amount, :edge, :stars, :fog, :fog_amount)
      def initialize(top:, mid:, bottom:, glow:, glow_at:, glow_amount:, edge:, stars:, fog: Color.hex("#000000"), fog_amount: 0.0) = super
    end

    # What a theme draws and plays beyond its colors, as one unit: +dot+
    # names its shader in assets/shaders/themes/, +sky+ and +scenery+ its
    # night (Presentation::Scenery), +wordmark+ the font of the game's name, if it has
    # its own, and whether the O's are dots (+dotted_name+), and
    # +sounds+ the patches it plays instead of the ordinary ones.
    class ThemeArt < Data.define(:dot, :sky, :scenery, :wordmark, :dotted_name, :sounds)
      def initialize(dot:, sky:, scenery:, wordmark: nil, dotted_name: false, sounds: {}) = super
    end

    # A theme for the whole game: its +key+ (what is saved of it, and what
    # the server names), its +palette+, and its +art+. The ordinary
    # theme has no art and is always there. Every theme lives in its own
    # file in presentation/themes/ with its shader in
    # assets/shaders/themes/, so one can be swapped alone. +opens_on+ is
    # the day after which it opens to everyone once setdef has been gone
    # for ThemeKeeper::GONE_DAYS, or nil for one that waits for a
    # replacement server to release it.
    class Theme < Data.define(:key, :palette, :art, :opens_on)
      def initialize(key:, palette:, art: nil, opens_on: nil) = super

      def ordinary? = art.nil?

      # The patches it plays in place of the ordinary ones (Style::PATCHES,
      # Shell::SoundPlayer#use): none for the ordinary theme, and for one with
      # art, its own over Style::THEMED_PATCHES.
      def sounds = ordinary? ? {} : Style::THEMED_PATCHES.merge(art.sounds)
    end
  end
end
