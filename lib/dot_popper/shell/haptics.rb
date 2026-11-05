# frozen_string_literal: true

module DotPopper
  module Shell
    # Buzzes the phone with Lota::System.vibrate. LÖVE vibrates only on
    # iOS and Android, and on iOS it ignores the length and plays the
    # system's long buzz (common/ios.mm, vibrate), which would run every
    # pop into the next; an iPad has no motor at all. So only Android
    # buzzes, and every other system gets NoHaptics. A device that cannot
    # buzz is no reason to stop the game.
    class Haptics
      BUZZING_SYSTEMS = %w[Android].freeze

      def self.for(os) = BUZZING_SYSTEMS.include?(os) ? new : Presentation::NoHaptics.new

      def buzz(seconds)
        ::Lota::System.vibrate(seconds) if seconds.positive?
      rescue StandardError => e
        warn "Dot Popper: could not buzz (#{e.message})"
      end
    end
  end
end
