# frozen_string_literal: true

module DotPopper
  module Presentation
    # A clipboard that only remembers what it was given, for tests and as
    # the Show's default; the shell's copies to the system's.
    class MemoryClipboard
      attr_reader :text

      def copy(text) = @text = text
    end
  end
end
