# frozen_string_literal: true

module DotPopper
  module Presentation
    # The title screen, shown since +at+, with the device's +best+ score:
    # how far its entrance has come, and the prompt's breath.
    class Marquee < Data.define(:look, :best, :at)
      def intro(now) = look.intro.at(now - at)

      # The prompt breathes, between +faintest+ and fully opaque, once
      # every +breath+ seconds.
      def prompt(now)
        swing = (1 - look.faintest) / 2.0
        1 - swing - (swing * Math.cos((now - at) * 2 * Math::PI / look.breath))
      end
    end
  end
end
