# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Ghosts over a foggy graveyard.
      module Ghost
        def self.theme(base, hex)
          Theme.new(
            key: :ghost, opens_on: Date.new(2026, 10, 1),
            palette: base.with(
              ink_top: hex["#0c1933"], ink_bottom: hex["#07101f"], ink_glow: hex["#1b3a52"], ink_edge: hex["#070d20"],
              bright_light: hex["#fbfdff"], bright_body: hex["#eef2ff"], bright_deep: hex["#c3cdeb"],
              bright_bounce: hex["#dfe7ff"], bright_rim: hex["#ffffff"], halo: hex["#c8e6ff"],
              popped_top: hex["#1f1a38"], popped_bottom: hex["#0e0c20"], popped_rim: hex["#6c6596"],
              popped_crater: hex["#0e0c20"], popped_lip: hex["#6a6090"],
              shadow: hex["#02020a"], alarm: hex["#ff7a9c"],
              cream: hex["#f3f6ff"], soft: hex["#a9b5d3"], gain: hex["#a7e4ff"], urgent: hex["#ff8fa0"],
              pill: hex["#0c1228", 0.8], pill_edge: hex["#6f7fb0", 0.8],
              confetti: [hex["#ffffff"], hex["#a7e4ff"], hex["#c7d2f0"], hex["#ff8fa0"], hex["#7f77ad"]].freeze
            ),
            art: ThemeArt.new(
              dot: "ghost", scenery: :graveyard,
              sky: ThemeSky.new(top: hex["#0c1933"], mid: hex["#13294a"], bottom: hex["#1b3a52"], glow: hex["#1b3a52"], glow_at: [0.5, 1.0],
                                glow_amount: 0.0, edge: hex["#070d20"], stars: 0.75, fog: hex["#5d7c97"], fog_amount: 0.55),
              title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 520, to: 190, length: 0.34, attack: 0.02, volume: 0.9),
                                       Note.new(wave: :triangle, from: 780, to: 280, length: 0.22, attack: 0.03, volume: 0.3)]),
                bonk: Patch.new(notes: [Note.new(wave: :sine, from: 220, to: 120, length: 0.5, attack: 0.04, volume: 0.9),
                                        Note.new(wave: :triangle, from: 110, to: 90, length: 0.5, attack: 0.05, volume: 0.5)])
              }
            )
          )
        end
      end
    end
  end
end
