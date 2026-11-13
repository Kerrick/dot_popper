# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # A tom turkey in full display, and the same turkey gone to roost when
      # popped, by a stand of oaks at nightfall.
      module Turkey
        def self.theme(base, hex)
          Theme.new(
            key: :turkey, opens_on: Date.new(2026, 11, 1),
            palette: base.with(
              ink_top: hex["#12101f"], ink_bottom: hex["#1e1420"], ink_glow: hex["#3a2422"], ink_edge: hex["#08060e"],
              bright_light: hex["#fff4dc"], bright_body: hex["#f8b45a"], bright_deep: hex["#d9772a"],
              bright_bounce: hex["#ffd79a"], bright_rim: hex["#ffeec8"], halo: hex["#ffc77f"],
              popped_top: hex["#2a1c1e"], popped_bottom: hex["#150e10"], popped_rim: hex["#786260"],
              popped_crater: hex["#0a0608"], popped_lip: hex["#5a464c"],
              shadow: hex["#040205"], alarm: hex["#ff5a5a"],
              cream: hex["#fff1dc"], soft: hex["#d0b8a8"], gain: hex["#ffd27a"], urgent: hex["#ff7a5e"],
              pill: hex["#120c16", 0.85], pill_edge: hex["#b0703a", 0.8],
              confetti: [hex["#c8451a"], hex["#fa8a28"], hex["#ffcc52"], hex["#fff1dc"], hex["#7a4a26"]].freeze
            ),
            art: ThemeArt.new(
              dot: "turkey", scenery: :roost,
              sky: ThemeSky.new(top: hex["#121028"], mid: hex["#2c1e3e"], bottom: hex["#5a3036"], glow: hex["#e8843e"], glow_at: [0.5, 1.02],
                                glow_amount: 0.4, edge: hex["#08060e"], stars: 0.7),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                # A gobble: a quick warble of falling notes, pitched low.
                pop: Patch.new(notes: [Note.new(wave: :triangle, from: 521, to: 437, length: 0.04, attack: 0.003, volume: 0.6),
                                       Note.new(wave: :triangle, from: 471, to: 370, start: 0.04, length: 0.04, attack: 0.003, volume: 0.55),
                                       Note.new(wave: :triangle, from: 505, to: 395, start: 0.08, length: 0.04, attack: 0.003, volume: 0.5),
                                       Note.new(wave: :triangle, from: 437, to: 320, start: 0.12, length: 0.06, attack: 0.003, volume: 0.45),
                                       Note.new(wave: :noise, from: 1, length: 0.03, attack: 0.002, volume: 0.15)]),
                # A low, cross "putt".
                bonk: Patch.new(notes: [Note.new(wave: :square, from: 220, to: 140, length: 0.09, attack: 0.004, volume: 0.35),
                                        Note.new(wave: :triangle, from: 140, to: 80, length: 0.22, volume: 0.9),
                                        Note.new(wave: :noise, from: 1, length: 0.05, attack: 0.002, volume: 0.35)])
              }
            )
          )
        end
      end
    end
  end
end
