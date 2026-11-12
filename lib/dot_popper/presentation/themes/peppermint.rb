# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Peppermints in a parlor by firelight; crunched, in shadow, when
      # popped.
      module Peppermint
        def self.theme(base, hex)
          Theme.new(
            key: :peppermint, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0c1f1a"], ink_bottom: hex["#0a1612"], ink_glow: hex["#1c3a2c"], ink_edge: hex["#040c09"],
              fresh_light: hex["#ffffff"], fresh_body: hex["#fbf6f4"], fresh_deep: hex["#e3d6da"],
              fresh_bounce: hex["#ffe8e8"], fresh_rim: hex["#fffaf8"], halo: hex["#ffd6d6"],
              popped_top: hex["#3a1a22"], popped_bottom: hex["#1e0c12"], popped_rim: hex["#7e6a74"],
              popped_crater: hex["#070306"], popped_lip: hex["#6a4a56"],
              shadow: hex["#020504"], alarm: hex["#ff6a7a"],
              cream: hex["#fff4ee"], soft: hex["#bcd0c6"], gain: hex["#a9e6c8"], urgent: hex["#ff8a8a"],
              pill: hex["#06120e", 0.85], pill_edge: hex["#d84a5a", 0.8],
              confetti: [hex["#ffffff"], hex["#e2283a"], hex["#ffd0d4"], hex["#3f8f6a"], hex["#f4e8ea"]].freeze
            ),
            art: ThemeArt.new(
              dot: "peppermint", scenery: :mantel,
              sky: ThemeSky.new(top: hex["#0c1f1a"], mid: hex["#123026"], bottom: hex["#2e2414"], glow: hex["#c0682c"], glow_at: [0.5, 0.86],
                                glow_amount: 0.4, edge: hex["#040c09"], stars: 0.0),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.045, attack: 0.001, volume: 0.55),
                                       Note.new(wave: :noise, from: 1, start: 0.035, length: 0.04, attack: 0.001, volume: 0.4),
                                       Note.new(wave: :noise, from: 1, start: 0.07, length: 0.03, attack: 0.001, volume: 0.25),
                                       Note.new(wave: :sine, from: 3520, to: 2960, length: 0.08, attack: 0.001, volume: 0.22),
                                       Note.new(wave: :sine, from: 5274, start: 0.04, length: 0.05, attack: 0.001, volume: 0.1)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 150, to: 95, length: 0.26, attack: 0.01, volume: 0.9),
                                        Note.new(wave: :noise, from: 1, length: 0.05, attack: 0.002, volume: 0.25)])
              }
            )
          )
        end
      end
    end
  end
end
