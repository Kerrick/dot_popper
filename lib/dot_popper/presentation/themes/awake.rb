# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # A dark wood full of shut eyes, and one open.
      module Awake
        def self.theme(base, hex)
          Theme.new(
            key: :awake,
            palette: base.with(
              ink_top: hex["#0e1a14"], ink_bottom: hex["#101f18"], ink_glow: hex["#16261d"], ink_edge: hex["#040604"],
              bright_light: hex["#fff8a2"], bright_body: hex["#f6e43a"], bright_deep: hex["#d29a14"],
              bright_bounce: hex["#fff8a2"], bright_rim: hex["#fffde2"], halo: hex["#f6d84a"],
              popped_top: hex["#37463a"], popped_bottom: hex["#1b261e"], popped_rim: hex["#7f8a79"],
              popped_crater: hex["#1b261e"], popped_lip: hex["#707a6b"],
              shadow: hex["#030503"], alarm: hex["#ff7a4d"],
              cream: hex["#efeed4"], soft: hex["#9fa98f"], gain: hex["#f6e43a"], urgent: hex["#ff7a4d"],
              pill: hex["#060907", 0.9], pill_edge: hex["#858f7d", 0.8],
              confetti: [hex["#f6e43a"], hex["#efeed4"], hex["#d29a14"], hex["#858f7d"], hex["#ff7a4d"]].freeze
            ),
            art: ThemeArt.new(
              dot: "awake", scenery: :wood,
              sky: ThemeSky.new(top: hex["#0e1a14"], mid: hex["#121f18"], bottom: hex["#16261d"], glow: hex["#26382a"], glow_at: [0.5, 1.0],
                                glow_amount: 0.25, edge: hex["#040604"], stars: 0.0),
              wordmark: "assets/fonts/Anton-Regular.ttf", dotted_name: true,
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.03, attack: 0.001, volume: 0.5),
                                       Note.new(wave: :sine, from: 880, to: 300, length: 0.09, volume: 0.6)]),
                bonk: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.2, attack: 0.04, volume: 0.6),
                                        Note.new(wave: :triangle, from: 90, to: 70, length: 0.25, volume: 0.6)])
              }
            )
          )
        end
      end
    end
  end
end
