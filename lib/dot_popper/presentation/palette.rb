# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every color in the game, by the job it does. "Gumdrops at night":
    # glossy candy on deep ink-indigo.
    #
    # A fresh dot and a popped one differ by lightness first, so they read
    # apart in grayscale and for colorblind players: a fresh dot is light,
    # warm and glossy, with a bright rim at its very edge; a popped dot is
    # dark, matte, opaque, with a thin rim and a sunken crater. Hue only adds to that.
    #
    # A bonus dot is a fresh dot in mint, as light as any, and marked by a
    # dark star, a shape, so it reads without color too. Mint is the color
    # of gain (+1s), the reward it pays.
    class Palette < Data.define(
      :ink_top, :ink_bottom, :ink_glow, :ink_edge,
      :fresh_light, :fresh_body, :fresh_deep, :fresh_bounce, :fresh_rim, :gloss, :halo,
      :bonus_light, :bonus_body, :bonus_deep, :bonus_bounce, :bonus_rim, :bonus_mark,
      :popped_top, :popped_bottom, :popped_rim, :popped_crater, :popped_lip,
      :shadow, :alarm, :cream, :soft, :gain, :urgent, :pill, :pill_edge, :confetti
    )
    end
  end
end
