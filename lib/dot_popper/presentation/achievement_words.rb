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

      def self.name(id) = NAMES.fetch(id)
      def self.mark(id) = MARKS.fetch(id)

      # "Achievements: 3 of 11", over the list.
      def self.heading(earned) = "Achievements: #{earned} of #{Achievement::IDS.size}"

      # What Game Over says of the +ids+ a game earned: "New achievement:
      # Sharpshooter", or the names of two or more.
      def self.earned(ids) = "#{ids.one? ? "New achievement" : "New achievements"}: #{ids.map { name(it) }.join(", ")}"
    end
  end
end
