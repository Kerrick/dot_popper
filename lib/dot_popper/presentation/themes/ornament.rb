# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Glass ornaments on a tree, lit, and dark when popped.
      module Ornament
        def self.theme(base, hex)
          Theme.new(
            key: :ornament, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0b1a17"], ink_bottom: hex["#0c1420"], ink_glow: hex["#1c2c26"], ink_edge: hex["#040a08"],
              fresh_light: hex["#fffbea"], fresh_body: hex["#ffe6a8"], fresh_deep: hex["#d9a443"],
              fresh_bounce: hex["#fff0c4"], fresh_rim: hex["#fff8e0"], halo: hex["#ffd98a"],
              popped_top: hex["#16302a"], popped_bottom: hex["#0b1a17"], popped_rim: hex["#6f8279"],
              popped_crater: hex["#050d0b"], popped_lip: hex["#3f6355"],
              shadow: hex["#020605"], alarm: hex["#ff6a5a"],
              cream: hex["#fff4de"], soft: hex["#b9c9c0"], gain: hex["#a9e6d0"], urgent: hex["#ff7a6a"],
              pill: hex["#06100e", 0.85], pill_edge: hex["#b58b3a", 0.8],
              confetti: [hex["#ffe6a8"], hex["#d93a3a"], hex["#3f8f6a"], hex["#fff4de"], hex["#c9d6e0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "ornament", scenery: :boughs,
              sky: ThemeSky.new(top: hex["#0b1a17"], mid: hex["#0f2420"], bottom: hex["#1e2a22"], glow: hex["#6b4a22"], glow_at: [0.5, 1.05],
                                glow_amount: 0.4, edge: hex["#040a08"], stars: 0.0),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 2093, length: 0.22, attack: 0.001, volume: 0.6),
                                       Note.new(wave: :sine, from: 3136, length: 0.12, attack: 0.001, volume: 0.25),
                                       Note.new(wave: :sine, from: 5274, length: 0.05, attack: 0.001, volume: 0.1),
                                       Note.new(wave: :noise, from: 1, length: 0.008, attack: 0.001, volume: 0.2)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 190, to: 95, length: 0.22, volume: 0.9),
                                        Note.new(wave: :noise, from: 1, length: 0.04, attack: 0.002, volume: 0.35)])
              }
            )
          )
        end
      end
    end
  end
end
