# frozen_string_literal: true

module DotPopper
  module Presentation
    # A clipboard that only remembers what it was given, and gives it back, for tests and as
    # the Show's default; the shell's copies to the system's.
    class MemoryClipboard
      attr_reader :text

      def initialize(text = nil) = @text = text

      def copy(text) = @text = text
      def paste = @text
    end
  end
end
