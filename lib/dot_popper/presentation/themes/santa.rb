# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Santa's face over snowy rooftops at night; asleep when popped.
      module Santa
        def self.theme(base, hex)
          Theme.new(
            key: :santa, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0a1230"], ink_bottom: hex["#0b1026"], ink_glow: hex["#1c2a52"], ink_edge: hex["#050818"],
              bright_light: hex["#ffffff"], bright_body: hex["#fbf6f0"], bright_deep: hex["#d9dbe6"],
              bright_bounce: hex["#ffe9de"], bright_rim: hex["#fff8f0"], halo: hex["#ffe8d6"],
              popped_top: hex["#1d1d2c"], popped_bottom: hex["#11111c"], popped_rim: hex["#6e6f8c"],
              popped_crater: hex["#06060c"], popped_lip: hex["#4c4d66"],
              shadow: hex["#02030a"], alarm: hex["#ff6a6a"],
              cream: hex["#fff6ee"], soft: hex["#b9bfd8"], gain: hex["#ffd0c4"], urgent: hex["#ff8a7a"],
              pill: hex["#070b20", 0.85], pill_edge: hex["#d84a4a", 0.8],
              confetti: [hex["#ffffff"], hex["#e23a3a"], hex["#ffd0c4"], hex["#3f8f6a"], hex["#c9d2f0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "santa", scenery: :rooftops,
              sky: ThemeSky.new(top: hex["#0a1230"], mid: hex["#14204a"], bottom: hex["#2a3a6a"], glow: hex["#3a4c80"], glow_at: [0.7, 1.0],
                                glow_amount: 0.35, edge: hex["#050818"], stars: 0.9),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", dotted_name: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 523, length: 0.12, attack: 0.001, volume: 0.45),
                                       Note.new(wave: :sine, from: 698, start: 0.03, length: 0.1, attack: 0.001, volume: 0.35),
                                       Note.new(wave: :sine, from: 622, start: 0.06, length: 0.14, attack: 0.001, volume: 0.35),
                                       Note.new(wave: :noise, from: 1, length: 0.1, attack: 0.002, volume: 0.12),
                                       Note.new(wave: :sine, from: 1047, start: 0.06, length: 0.05, attack: 0.001, volume: 0.1)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 130, to: 98, length: 0.32, attack: 0.03, volume: 0.9),
                                        Note.new(wave: :sine, from: 196, to: 147, length: 0.3, attack: 0.03, volume: 0.4)])
              }
            )
          )
        end
      end
    end
  end
end
