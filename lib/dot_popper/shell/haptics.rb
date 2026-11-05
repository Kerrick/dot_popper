# frozen_string_literal: true

module DotPopper
  module Shell
    # Buzzes the phone or tablet with Lota::System.vibrate. LÖVE vibrates
    # only on iOS and Android, so every other system gets NoHaptics; a
    # device that cannot buzz is no reason to stop the game.
    class Haptics
      def self.for(os) = DotSize.touch?(os) ? new : Presentation::NoHaptics.new

      def buzz(seconds)
        ::Lota::System.vibrate(seconds) if seconds.positive?
      rescue StandardError => e
        warn "Dot Popper: could not buzz (#{e.message})"
      end
    end
  end
end
