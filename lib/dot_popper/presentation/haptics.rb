# frozen_string_literal: true

module DotPopper
  module Presentation
    # How long the phone buzzes, in seconds, for a pop and for a wrong
    # tap; 0 is no buzz. A wrong tap's is longer, so the two feel apart.
    class HapticsLook < Data.define(:pop, :penalty); end

    # Haptics for a device that has none, and for the tests: it never
    # buzzes. Anything that answers +buzz(seconds)+ can stand in for it.
    class NoHaptics < Data.define
      def buzz(_seconds) = nil
    end
  end
end
