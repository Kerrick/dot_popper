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
                # A hard candy bitten through: one sharp crack, the jaw's
                # dull thud, a few crumbs breaking at uneven times, and a
                # faint glassy ring of sugar.
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.012, attack: 0.0005, volume: 0.6),
                                       Note.new(wave: :triangle, from: 300, to: 150, length: 0.09, attack: 0.002, volume: 0.55),
                                       Note.new(wave: :noise, from: 1, start: 0.011, length: 0.006, attack: 0.0005, volume: 0.28),
                                       Note.new(wave: :noise, from: 1, start: 0.027, length: 0.009, attack: 0.0005, volume: 0.2),
                                       Note.new(wave: :noise, from: 1, start: 0.034, length: 0.005, attack: 0.0005, volume: 0.14),
                                       Note.new(wave: :noise, from: 1, start: 0.058, length: 0.007, attack: 0.0005, volume: 0.09),
                                       Note.new(wave: :sine, from: 784, to: 740, length: 0.05, attack: 0.001, volume: 0.12)]),
                # A mint dropped on the candy dish: a dull, flat clunk.
                bonk: Patch.new(notes: [Note.new(wave: :sine, from: 196, to: 165, length: 0.24, attack: 0.002, volume: 0.85),
                                        Note.new(wave: :sine, from: 498, to: 470, length: 0.08, attack: 0.001, volume: 0.3),
                                        Note.new(wave: :triangle, from: 98, to: 82, length: 0.2, attack: 0.004, volume: 0.4),
                                        Note.new(wave: :noise, from: 1, length: 0.006, attack: 0.0005, volume: 0.3)]),
                # A spearmint arrives: a celesta, down and back up.
                bonus: Patch.new(notes: [1174.66, 880.0, 1174.66, 1479.98].each_with_index.flat_map do |hz, i|
                  [Note.new(wave: :sine, from: hz, start: i * 0.07, length: 0.3, attack: 0.002, volume: 0.6),
                   Note.new(wave: :sine, from: hz * 2, start: i * 0.07, length: 0.1, attack: 0.001, volume: 0.12)]
                end),
                # A spearmint is popped: under its own crunch, a celesta's
                # chord rolled up.
                bonus_pop: Patch.new(notes: [587.33, 880.0, 1174.66, 1479.98].each_with_index.flat_map do |hz, i|
                  [Note.new(wave: :sine, from: hz, start: 0.04 + (i * 0.03), length: 0.45, attack: 0.002, volume: 0.6 - (i * 0.08)),
                   Note.new(wave: :sine, from: hz * 2, start: 0.04 + (i * 0.03), length: 0.12, attack: 0.001, volume: 0.1)]
                end)
              }
            )
          )
        end
      end
    end
  end
end
