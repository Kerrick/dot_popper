# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Silver jingle bells over a sleigh ride through the snow at night;
      # burst open along the slot, in shadow, when popped.
      module JingleBell
        def self.theme(base, hex)
          Theme.new(
            key: :jingle_bell, opens_on: Date.new(2026, 12, 1),
            palette: base.with(
              ink_top: hex["#120d2e"], ink_bottom: hex["#0c0a1e"], ink_glow: hex["#2a1c4c"], ink_edge: hex["#070514"],
              fresh_light: hex["#ffffff"], fresh_body: hex["#eef0f6"], fresh_deep: hex["#c4c8d6"],
              fresh_bounce: hex["#f4f6ff"], fresh_rim: hex["#fafbff"], halo: hex["#dde6ff"],
              popped_top: hex["#22232e"], popped_bottom: hex["#13131c"], popped_rim: hex["#6e7088"],
              popped_crater: hex["#050508"], popped_lip: hex["#4e5064"],
              shadow: hex["#020208"], alarm: hex["#ff6a7a"],
              cream: hex["#f6f6ff"], soft: hex["#b8bcda"], gain: hex["#ffd6a0"], urgent: hex["#ff8a8a"],
              pill: hex["#090a1e", 0.85], pill_edge: hex["#d84a5a", 0.8],
              confetti: [hex["#ffffff"], hex["#e2283a"], hex["#ffd98a"], hex["#3f8f6a"], hex["#c9d2f0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "jingle_bell", scenery: :sleigh_ride,
              sky: ThemeSky.new(top: hex["#120d2e"], mid: hex["#2a1c4c"], bottom: hex["#6a3a62"], glow: hex["#b0607a"], glow_at: [0.65, 0.78],
                                glow_amount: 0.4, edge: hex["#070514"], stars: 0.8),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 1975, length: 0.16, attack: 0.001, volume: 0.4),
                                       Note.new(wave: :sine, from: 2637, length: 0.12, attack: 0.001, volume: 0.25),
                                       Note.new(wave: :sine, from: 4186, length: 0.06, attack: 0.001, volume: 0.12),
                                       Note.new(wave: :noise, from: 1, length: 0.025, attack: 0.001, volume: 0.15),
                                       Note.new(wave: :sine, from: 2093, start: 0.07, length: 0.18, attack: 0.001, volume: 0.3),
                                       Note.new(wave: :sine, from: 2794, start: 0.07, length: 0.13, attack: 0.001, volume: 0.18),
                                       Note.new(wave: :noise, from: 1, start: 0.07, length: 0.02, attack: 0.001, volume: 0.1)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 196, to: 130, length: 0.24, attack: 0.005, volume: 0.85),
                                        Note.new(wave: :square, from: 98, to: 82, length: 0.12, attack: 0.005, volume: 0.12)])
              }
            )
          )
        end
      end
    end
  end
end
