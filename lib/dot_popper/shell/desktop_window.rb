# frozen_string_literal: true

module DotPopper
  module Shell
    # The game's window on a desktop, as Settings' Display choice and F11,
    # Alt+Enter (Cmd+Enter on a Mac), Quit and Escape move and close it:
    # :window, :borderless (LÖVE's desktop fullscreen), or :exclusive (its
    # real fullscreen). F11 switches between a window and the last
    # fullscreen choice, which it remembers, so the window is a plain
    # object rather than a frozen value. +lota+ is Lota's Window, or a
    # stand-in for the tests.
    class DesktopWindow
      def initialize(exclusive: false, lota: ::Lota::Window)
        @exclusive = exclusive
        @lota = lota
        @last = nil
      end

      def offered? = true

      def fullscreen?
        on, = @lota.fullscreen
        on
      end

      # Which of the three the window is in now.
      def display
        on, type = @lota.fullscreen
        return :window unless on

        type.to_s == "exclusive" ? :exclusive : :borderless
      end

      def display=(mode)
        @last = mode unless mode == :window
        case mode
        when :window then @lota.set_fullscreen(false, :desktop)
        when :borderless then @lota.set_fullscreen(true, :desktop)
        when :exclusive then @lota.set_fullscreen(true, :exclusive)
        end
      end

      def toggle_fullscreen
        self.display = fullscreen? ? :window : (@last || (@exclusive ? :exclusive : :borderless))
      end

      def quit = ::Lota::Event.quit
    end
  end
end
