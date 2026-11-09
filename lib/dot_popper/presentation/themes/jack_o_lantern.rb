# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Carved pumpkins, lit from inside, at dusk.
      module JackOLantern
        def self.theme(base, hex)
          Theme.new(
            key: :jack_o_lantern,
            palette: base.with(
              ink_top: hex["#1c1442"], ink_bottom: hex["#2a1a3a"], ink_glow: hex["#3a1f5e"], ink_edge: hex["#0b0820"],
              fresh_light: hex["#fff6c2"], fresh_body: hex["#ffa11f"], fresh_deep: hex["#b6480b"],
              fresh_bounce: hex["#ffd64d"], fresh_rim: hex["#ffd690"], halo: hex["#ffb24a"],
              popped_top: hex["#301e25"], popped_bottom: hex["#1a1016"], popped_rim: hex["#7d6b66"],
              popped_crater: hex["#040203"], popped_lip: hex["#6a4a3e"],
              shadow: hex["#040208"], alarm: hex["#ff5a5a"],
              cream: hex["#fff0d2"], soft: hex["#c9b6a0"], gain: hex["#ffc14a"], urgent: hex["#ff6a5a"],
              pill: hex["#160e24", 0.85], pill_edge: hex["#a4661f", 0.8],
              confetti: [hex["#ffa11f"], hex["#ffd64d"], hex["#ff7a14"], hex["#fff6c2"], hex["#7e9a44"]].freeze
            ),
            art: ThemeArt.new(
              dot: "jack_o_lantern", scenery: :dusk,
              sky: ThemeSky.new(top: hex["#1c1442"], mid: hex["#3a1f5e"], bottom: hex["#6d2b4a"], glow: hex["#ffb060"], glow_at: [0.5, 1.02],
                                glow_amount: 0.35, edge: hex["#0b0820"], stars: 0.85),
              wordmark: "assets/fonts/Creepster.ttf", title_dots: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.09, attack: 0.002, volume: 0.45),
                                       Note.new(wave: :triangle, from: 240, to: 110, length: 0.16, volume: 0.9)]),
                bonk: Patch.new(notes: [Note.new(wave: :triangle, from: 95, to: 60, length: 0.32, volume: 1.0),
                                        Note.new(wave: :noise, from: 1, length: 0.05, volume: 0.4)])
              }
            )
          )
        end
      end
    end
  end
end
