# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Iced gingerbread cookies in a kitchen on a snowy night; in shadow,
      # the gingerbread man run away, when popped.
      module Gingerbread
        def self.theme(base, hex)
          Theme.new(
            key: :gingerbread, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#0e1422"], ink_bottom: hex["#0a0e18"], ink_glow: hex["#24304a"], ink_edge: hex["#05070e"],
              fresh_light: hex["#fff4e0"], fresh_body: hex["#e8b070"], fresh_deep: hex["#c88848"],
              fresh_bounce: hex["#f4c890"], fresh_rim: hex["#fff2dc"], halo: hex["#ffd9a0"],
              popped_top: hex["#3a2418"], popped_bottom: hex["#24140c"], popped_rim: hex["#8a6e5e"],
              popped_crater: hex["#0a0604"], popped_lip: hex["#6a5040"],
              shadow: hex["#030406"], alarm: hex["#ff6a7a"],
              cream: hex["#fff4e6"], soft: hex["#c4c0cc"], gain: hex["#a9e6c8"], urgent: hex["#ff8a8a"],
              pill: hex["#080b14", 0.85], pill_edge: hex["#c88848", 0.8],
              confetti: [hex["#fff4e0"], hex["#e2283a"], hex["#e8b070"], hex["#3f8f6a"], hex["#c9d2f0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "gingerbread", scenery: :kitchen,
              sky: ThemeSky.new(top: hex["#0e1422"], mid: hex["#162034"], bottom: hex["#2a2a3a"], glow: hex["#b0703a"], glow_at: [0.5, 1.0],
                                glow_amount: 0.35, edge: hex["#05070e"], stars: 0.0),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.03, attack: 0.001, volume: 0.4),
                                       Note.new(wave: :triangle, from: 660, to: 1320, start: 0.02, length: 0.07, attack: 0.002, volume: 0.35),
                                       Note.new(wave: :triangle, from: 880, to: 1760, start: 0.08, length: 0.06, attack: 0.002, volume: 0.25),
                                       Note.new(wave: :triangle, from: 1175, to: 2349, start: 0.13, length: 0.05, attack: 0.002, volume: 0.18)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 140, to: 90, length: 0.24, attack: 0.01, volume: 0.9),
                                        Note.new(wave: :noise, from: 1, length: 0.04, attack: 0.002, volume: 0.2)])
              }
            )
          )
        end
      end
    end
  end
end
