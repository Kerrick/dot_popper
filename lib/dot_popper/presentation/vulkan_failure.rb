# frozen_string_literal: true

require "date"

module DotPopper
  module Presentation
    # The note the game keeps in its save folder once Vulkan failed to
    # start it on this computer: the day it did. For LASTS days after,
    # the game starts without Vulkan. Then it tries Vulkan again, in case
    # a new driver made it work, and if it still fails, falls back again
    # by itself, as it did the first time.
    class VulkanFailure < Data.define(:day)
      LASTS = 30

      # The note +text+ holds, or nil for no note or one that isn't a day.
      def self.parse(text)
        new(day: Date.iso8601(text.to_s.strip))
      rescue Date::Error
        nil
      end

      # Whether the game should still start without Vulkan on +today+. A
      # clock set back keeps the note.
      def holds?(today) = today - day < LASTS

      # The first day the game tries Vulkan again.
      def retry_on = day + LASTS

      def to_s = day.iso8601
    end
  end
end
