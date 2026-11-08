# frozen_string_literal: true

module DotPopper
  module Presentation
    # The words for the feats (Feat): each one's name, and its mark, the
    # short figure that says what it asks, which reads the same in any
    # language, the Records screen's heading over them, and Game Over's
    # line for the ones a round earned.
    module FeatWords
      NAMES = {
        sharpshooter: "Sharpshooter", sharp_trio: "Sharp trio", patience: "Patience", blink: "Blink",
        steady: "Steady hand", unshaken: "Unshaken", shake_off: "Shake it off", comeback: "Back from the brink",
        fast_start: "Fast start", big_score: "Big score", long_haul: "Long haul"
      }.freeze

      # What each asks, as a figure: less of the dot showing than this,
      # how many, how long.
      MARKS = {
        sharpshooter: "<#{(Feat::SHARP * 100).round}%", sharp_trio: "3 × <#{(Feat::SHARP_TRIO_BELOW * 100).round}%",
        patience: "#{Feat::PATIENCE.to_i} s", blink: "<#{Feat::BLINK} s", steady: Feat::STEADY.to_s,
        unshaken: Feat::UNSHAKEN.to_s, shake_off: Feat::SHAKE_OFF.to_s,
        comeback: "#{Feat::BRINK.to_i} to #{Feat::BACK.to_i} s",
        fast_start: "#{Feat::FAST_START} in #{Feat::FAST_START_SECONDS.to_i} s", big_score: Feat::BIG_SCORE.to_s,
        long_haul: "#{Feat::LONG_HAUL.to_i} s"
      }.freeze

      LOCKED_HEADING = "Feats come with the full game"

      def self.name(id) = NAMES.fetch(id)
      def self.mark(id) = MARKS.fetch(id)

      # "Feats: 3 of 11", over the list.
      def self.heading(earned) = "Feats: #{earned} of #{Feat::IDS.size}"

      # What Game Over says of the +ids+ a round earned: "New feat:
      # Sharpshooter", or the names of two or more.
      def self.earned(ids) = "#{ids.one? ? "New feat" : "New feats"}: #{ids.map { name(it) }.join(", ")}"
    end
  end
end
