# frozen_string_literal: true

module DotPopper
  module Presentation
    # The words for the achievements (Achievement): each one's name, and its mark, the
    # short figure that says what it asks, which reads the same in any
    # language, the Stats screen's heading over them, and Game Over's
    # line for the ones a game earned.
    module AchievementWords
      NAMES = {
        sharpshooter: "Sharpshooter", sharp_trio: "Sharp trio", patience: "Patience", blink: "Blink",
        steady: "Steady hand", unshaken: "Unshaken", shake_off: "Shake it off", comeback: "Back from the brink",
        fast_start: "Fast start", big_score: "Big score", long_haul: "Long haul"
      }.freeze

      # What each asks, as a figure: less of the dot showing than this,
      # how many, how long.
      MARKS = {
        sharpshooter: "<#{(Achievement::SHARP * 100).round}%", sharp_trio: "3 × <#{(Achievement::SHARP_TRIO_BELOW * 100).round}%",
        patience: "#{Achievement::PATIENCE.to_i} s", blink: "<#{Achievement::BLINK} s", steady: Achievement::STEADY.to_s,
        unshaken: Achievement::UNSHAKEN.to_s, shake_off: Achievement::SHAKE_OFF.to_s,
        comeback: "#{Achievement::BRINK.to_i} to #{Achievement::BACK.to_i} s",
        fast_start: "#{Achievement::FAST_START} in #{Achievement::FAST_START_SECONDS.to_i} s", big_score: Achievement::BIG_SCORE.to_s,
        long_haul: "#{Achievement::LONG_HAUL.to_i} s"
      }.freeze

      # How each is earned, in a sentence a player can act on.
      HOW = {
        sharpshooter: "Pop a bright dot with less than #{(Achievement::SHARP * 100).round}% of it showing.",
        sharp_trio: "Pop #{Achievement::SHARP_TRIO} bright dots in one game with less than #{(Achievement::SHARP_TRIO_BELOW * 100).round}% of each showing.",
        patience: "When a bright dot appears with no clear spot to tap, tap nothing for at least #{Achievement::PATIENCE.to_i} seconds, then pop it.",
        blink: "Pop a bright dot within #{Achievement::BLINK} seconds of the one before.",
        steady: "Pop #{Achievement::STEADY} dots in a row without a mistake, in one game.",
        unshaken: "Pop #{Achievement::UNSHAKEN} dots in a row without a mistake, in one game.",
        shake_off: "After a mistake, pop #{Achievement::SHAKE_OFF} dots in a row without another.",
        comeback: "Let the clock fall to #{Achievement::BRINK.to_i} seconds, then bring it back to #{Achievement::BACK.to_i}.",
        fast_start: "Pop #{Achievement::FAST_START} bright dots in the first #{Achievement::FAST_START_SECONDS.to_i} seconds of a game.",
        big_score: "Score #{Achievement::BIG_SCORE} points in one game.",
        long_haul: "Keep one game going for #{Achievement::LONG_HAUL.to_i} seconds."
      }.freeze
      # The glyphs (Shell::Glyphs) each is drawn with, named after what it asks.
      GLYPHS = { sharpshooter: :crosshair, sharp_trio: :trio, patience: :hourglass, blink: :eye, steady: :hand, unshaken: :mountain,
                 shake_off: :shake, comeback: :stairs, fast_start: :bolt, big_score: :star, long_haul: :road }.freeze

      def self.how(id) = HOW.fetch(id)
      def self.glyph(id) = GLYPHS.fetch(id)
      def self.name(id) = NAMES.fetch(id)
      def self.earned_on(day) = "Earned #{Date.iso8601(day).strftime("%B %-d, %Y")}"
      def self.count(earned) = "#{earned} of #{Achievement::IDS.size}"
      def self.mark(id) = MARKS.fetch(id)

      # "Achievements: 3 of 11", over the list.
      def self.heading(earned) = "Achievements: #{earned} of #{Achievement::IDS.size}"

      # What Game Over says of the +ids+ a game earned: "New achievement:
      # Sharpshooter", or the names of two or more.
      def self.earned(ids) = "#{ids.one? ? "New achievement" : "New achievements"}: #{ids.map { name(it) }.join(", ")}"
    end
  end
end
