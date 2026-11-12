# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Mirrored gold glass ornaments on a tree; broken, dark red glass in
      # shadow, when popped.
      module Ornament
        def self.theme(base, hex)
          Theme.new(
            key: :ornament, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0b1a17"], ink_bottom: hex["#0c1420"], ink_glow: hex["#1c2c26"], ink_edge: hex["#040a08"],
              fresh_light: hex["#fffbea"], fresh_body: hex["#ffe6a8"], fresh_deep: hex["#d9a443"],
              fresh_bounce: hex["#fff0c4"], fresh_rim: hex["#fff8e0"], halo: hex["#ffd98a"],
              popped_top: hex["#3a1018"], popped_bottom: hex["#1c070c"], popped_rim: hex["#8a6670"],
              popped_crater: hex["#0a0305"], popped_lip: hex["#6e3e48"],
              shadow: hex["#020605"], alarm: hex["#ff6a5a"],
              cream: hex["#fff4de"], soft: hex["#b9c9c0"], gain: hex["#a9e6d0"], urgent: hex["#ff7a6a"],
              pill: hex["#06100e", 0.85], pill_edge: hex["#b58b3a", 0.8],
              confetti: [hex["#ffe6a8"], hex["#d93a3a"], hex["#3f8f6a"], hex["#fff4de"], hex["#c9d6e0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "ornament", scenery: :boughs,
              sky: ThemeSky.new(top: hex["#0d2620"], mid: hex["#173a2f"], bottom: hex["#4a3418"], glow: hex["#b8742c"], glow_at: [0.5, 1.02],
                                glow_amount: 0.55, edge: hex["#06100d"], stars: 0.0),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 523, length: 0.26, attack: 0.001, volume: 0.55),
                                       Note.new(wave: :sine, from: 784, length: 0.14, attack: 0.001, volume: 0.25),
                                       Note.new(wave: :noise, from: 1, length: 0.05, attack: 0.001, volume: 0.35),
                                       Note.new(wave: :sine, from: 831, start: 0.05, length: 0.06, attack: 0.001, volume: 0.18),
                                       Note.new(wave: :sine, from: 1047, start: 0.09, length: 0.05, attack: 0.001, volume: 0.14),
                                       Note.new(wave: :sine, from: 698, start: 0.13, length: 0.07, attack: 0.001, volume: 0.12)]),
                bonk: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.09, attack: 0.002, volume: 0.45),
                                        Note.new(wave: :triangle, from: 170, to: 90, length: 0.22, volume: 0.9)])
              }
            )
          )
        end
      end
    end
  end
end
