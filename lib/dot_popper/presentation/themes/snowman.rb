# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Snowmen in a snowy yard at night; melted into puddles when popped.
      module Snowman
        def self.theme(base, hex)
          Theme.new(
            key: :snowman, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0b1530"], ink_bottom: hex["#0e1a36"], ink_glow: hex["#22355e"], ink_edge: hex["#060b1c"],
              bright_light: hex["#ffffff"], bright_body: hex["#f4f8ff"], bright_deep: hex["#c3d0ea"],
              bright_bounce: hex["#e6eeff"], bright_rim: hex["#ffffff"], halo: hex["#d8e8ff"],
              popped_top: hex["#16203a"], popped_bottom: hex["#0c1222"], popped_rim: hex["#6c7898"],
              popped_crater: hex["#05070d"], popped_lip: hex["#4c5674"],
              shadow: hex["#02040a"], alarm: hex["#ff6a7a"],
              cream: hex["#f4f8ff"], soft: hex["#b4c2e0"], gain: hex["#ffb27a"], urgent: hex["#ff8a8a"],
              pill: hex["#070d22", 0.85], pill_edge: hex["#3f8f6a", 0.85],
              confetti: [hex["#ffffff"], hex["#c8d8f8"], hex["#ff8a3a"], hex["#3f8f6a"], hex["#d83a3a"]].freeze
            ),
            art: ThemeArt.new(
              dot: "snowman", scenery: :snowfield,
              sky: ThemeSky.new(top: hex["#0b1530"], mid: hex["#16264e"], bottom: hex["#34497a"], glow: hex["#5a6e9e"], glow_at: [0.3, 0.95],
                                glow_amount: 0.3, edge: hex["#060b1c"], stars: 0.8),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :triangle, from: 400, to: 210, length: 0.14, attack: 0.004, volume: 0.8),
                                       Note.new(wave: :sine, from: 200, to: 175, length: 0.16, attack: 0.006, volume: 0.5),
                                       Note.new(wave: :noise, from: 1, length: 0.04, attack: 0.012, volume: 0.1)]),
                bonk: Patch.new(notes: [Note.new(wave: :sine, from: 110, to: 70, length: 0.36, attack: 0.02, volume: 0.9),
                                        Note.new(wave: :triangle, from: 220, to: 140, length: 0.2, attack: 0.02, volume: 0.25)])
              }
            )
          )
        end
      end
    end
  end
end
