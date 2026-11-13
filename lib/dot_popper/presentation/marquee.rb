# frozen_string_literal: true

module DotPopper
  module Presentation
    # Home, shown since +at+, with the device's +best+ score:
    # how far its entrance has come, and the prompt's breath.
    class Marquee < Data.define(:style, :score_record, :at)
      def intro(now) = style.intro.at(now - at)

      # The prompt breathes, between +faintest+ and fully opaque, once
      # every +breath+ seconds.
      def prompt(now)
        swing = (1 - style.faintest) / 2.0
        1 - swing - (swing * Math.cos((now - at) * 2 * Math::PI / style.breath))
      end
    end
  end
end
