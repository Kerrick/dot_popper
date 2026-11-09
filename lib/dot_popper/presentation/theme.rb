# frozen_string_literal: true

module DotPopper
  module Presentation
    # The sky of a theme's night, as the scene shader takes it.
    class ThemeSky < Data.define(:top, :mid, :bottom, :glow, :glow_at, :glow_amount, :edge, :stars, :fog, :fog_amount)
      def initialize(top:, mid:, bottom:, glow:, glow_at:, glow_amount:, edge:, stars:, fog: Color.hex("#000000"), fog_amount: 0.0) = super
    end

    # What a theme draws and plays beyond its colors, as one unit: +dot+
    # names its shader in assets/shaders/themes/, +sky+ and +scenery+ its
    # night (Presentation::Scenery), +wordmark+ the title's font, if it has
    # its own, and whether the O's are dots (+title_dots+), and
    # +sounds+ the patches it plays instead of the ordinary ones.
    class ThemeArt < Data.define(:dot, :sky, :scenery, :wordmark, :title_dots, :sounds)
      def initialize(dot:, sky:, scenery:, wordmark: nil, title_dots: false, sounds: {}) = super
    end

    # A theme for the whole game: its +key+ (what is saved of it, and what
    # the server names), its +palette+, and its +art+. The ordinary
    # theme has no art and is always there. Every theme lives in its own
    # file in presentation/themes/ with its shader in
    # assets/shaders/themes/, so one can be swapped alone.
    class Theme < Data.define(:key, :palette, :art)
      def initialize(key:, palette:, art: nil) = super

      def ordinary? = art.nil?
    end
  end
end
