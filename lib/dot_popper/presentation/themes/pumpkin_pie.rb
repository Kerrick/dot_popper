# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Pumpkin pies, and the dish after dinner when popped, on a farm at
      # dusk on Thanksgiving.
      module PumpkinPie
        def self.theme(base, hex)
          Theme.new(
            key: :pumpkin_pie, opens_on: Date.new(2026, 11, 1),
            palette: base.with(
              ink_top: hex["#160f1e"], ink_bottom: hex["#22141e"], ink_glow: hex["#3a2026"], ink_edge: hex["#0a0610"],
              fresh_light: hex["#fff3d6"], fresh_body: hex["#f5ab5e"], fresh_deep: hex["#d9843a"],
              fresh_bounce: hex["#ffd49a"], fresh_rim: hex["#ffe2a8"], halo: hex["#ffc070"],
              popped_top: hex["#2e1714"], popped_bottom: hex["#1a0c0a"], popped_rim: hex["#7d5e54"],
              popped_crater: hex["#0a0608"], popped_lip: hex["#5a464c"],
              shadow: hex["#040205"], alarm: hex["#ff5a5a"],
              cream: hex["#fff1dc"], soft: hex["#cdb3a8"], gain: hex["#ffcf7a"], urgent: hex["#ff7a5e"],
              pill: hex["#120a14", 0.85], pill_edge: hex["#a8743a", 0.8],
              confetti: [hex["#f5ab5e"], hex["#ffe2a8"], hex["#b8452a"], hex["#fff1dc"], hex["#8a9a44"]].freeze
            ),
            art: ThemeArt.new(
              dot: "pumpkin_pie", scenery: :farm,
              sky: ThemeSky.new(top: hex["#17112a"], mid: hex["#33203a"], bottom: hex["#6e3530"], glow: hex["#ff9a4a"], glow_at: [0.45, 1.02],
                                glow_amount: 0.45, edge: hex["#0a0610"], stars: 0.6),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                # A soft plop, a forkful taken: one attack, its octave on
                # the same fall, and a breath of noise inside it.
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 340, to: 200, length: 0.15, attack: 0.003, volume: 0.9),
                                       Note.new(wave: :sine, from: 680, to: 400, length: 0.08, attack: 0.003, volume: 0.25),
                                       Note.new(wave: :noise, from: 1, length: 0.015, attack: 0.001, volume: 0.12)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 150, to: 80, length: 0.24, volume: 1.0),
                                        Note.new(wave: :noise, from: 1, length: 0.06, attack: 0.002, volume: 0.45)])
              }
            )
          )
        end
      end
    end
  end
end
