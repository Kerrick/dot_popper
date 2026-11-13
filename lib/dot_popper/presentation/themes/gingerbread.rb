# frozen_string_literal: true

module DotPopper
  module Presentation
    module Themes
      # Iced gingerbread cookies over icing and candy glass; in shadow,
      # the gingerbread man run away, when popped.
      module Gingerbread
        def self.theme(base, hex)
          Theme.new(
            key: :gingerbread,
            palette: base.with(
              ink_top: hex["#170c12"], ink_bottom: hex["#12090e"], ink_glow: hex["#3a1a24"], ink_edge: hex["#080406"],
              bright_light: hex["#fff4e0"], bright_body: hex["#e8b070"], bright_deep: hex["#c88848"],
              bright_bounce: hex["#f4c890"], bright_rim: hex["#fff2dc"], halo: hex["#ffd9a0"],
              popped_top: hex["#3a2418"], popped_bottom: hex["#24140c"], popped_rim: hex["#8a6e5e"],
              popped_crater: hex["#0a0604"], popped_lip: hex["#6a5040"],
              shadow: hex["#030406"], alarm: hex["#ff6a7a"],
              cream: hex["#fff4e6"], soft: hex["#c4c0cc"], gain: hex["#a9e6c8"], urgent: hex["#ff8a8a"],
              pill: hex["#12080c", 0.85], pill_edge: hex["#c88848", 0.8],
              confetti: [hex["#fff4e0"], hex["#e2283a"], hex["#e8b070"], hex["#3f8f6a"], hex["#c9d2f0"]].freeze
            ),
            art: ThemeArt.new(
              dot: "gingerbread", scenery: :icing,
              sky: ThemeSky.new(top: hex["#1e0f18"], mid: hex["#301424"], bottom: hex["#421a26"], glow: hex["#c0602a"], glow_at: [0.5, 1.05],
                                glow_amount: 0.22, edge: hex["#080406"], stars: 0.0),
              wordmark: "assets/fonts/Fredoka-Bold.ttf", dotted_name: true,
              sounds: {
                # A gumdrop's soft "boop": a light tap, one short note that
                # lifts a little, and a single small bounce above it.
                pop: Patch.new(notes: [Note.new(wave: :noise, from: 1, length: 0.008, attack: 0.0005, volume: 0.25),
                                       Note.new(wave: :sine, from: 555, to: 664, length: 0.06, attack: 0.003, volume: 0.6),
                                       Note.new(wave: :triangle, from: 277, to: 332, length: 0.06, attack: 0.003, volume: 0.2),
                                       Note.new(wave: :sine, from: 832, start: 0.05, length: 0.045, attack: 0.002, volume: 0.25)]),
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
