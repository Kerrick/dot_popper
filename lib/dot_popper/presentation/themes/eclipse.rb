# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Harvest moons, and moons in eclipse, over a churchyard.
      module Eclipse
        def self.theme(base, hex)
          Theme.new(
            key: :eclipse, opens_on: Date.new(2027, 10, 1),
            palette: base.with(
              ink_top: hex["#090b1e"], ink_bottom: hex["#1a1028"], ink_glow: hex["#2b1436"], ink_edge: hex["#05050f"],
              fresh_light: hex["#fff9e6"], fresh_body: hex["#fff0c8"], fresh_deep: hex["#d9a35a"],
              fresh_bounce: hex["#fff0c8"], fresh_rim: hex["#fff5d8"], halo: hex["#ffd98c"],
              popped_top: hex["#25101a"], popped_bottom: hex["#0d0812"], popped_rim: hex["#e0632f"],
              popped_crater: hex["#0d0812"], popped_lip: hex["#a43e26"],
              shadow: hex["#02020a"], alarm: hex["#ff5a3a"],
              cream: hex["#fbeed2"], soft: hex["#b7a8c6"], gain: hex["#a9e6d0"], urgent: hex["#ff7a55"],
              pill: hex["#07061a", 0.86], pill_edge: hex["#8d6a3a", 0.8],
              confetti: [hex["#fff0c8"], hex["#e0632f"], hex["#d9a35a"], hex["#a9e6d0"], hex["#fbeed2"]].freeze
            ),
            art: ThemeArt.new(
              dot: "eclipse", scenery: :churchyard,
              sky: ThemeSky.new(top: hex["#090b1e"], mid: hex["#141230"], bottom: hex["#2b1436"], glow: hex["#6b2a24"], glow_at: [0.42, 0.88],
                                glow_amount: 0.42, edge: hex["#05050f"], stars: 0.9),
              wordmark: "assets/fonts/IMFellDoublePica-Regular.ttf",
              sounds: {
                pop: Patch.new(notes: [Note.new(wave: :sine, from: 330, length: 0.5, volume: 0.9),
                                       Note.new(wave: :sine, from: 660, length: 0.25, volume: 0.3)]),
                bonk: Patch.new(notes: [Note.new(wave: :square, from: 180, to: 95, length: 0.24, volume: 0.5)])
              }
            )
          )
        end
      end
    end
  end
end
