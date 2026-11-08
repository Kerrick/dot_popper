# frozen_string_literal: true

module DotPopper
  module Shell
    # The game's window on a desktop, which the title's "Full screen" and
    # Quit switch and close, as F11, Alt+Enter (Cmd+Enter on a Mac) and
    # Escape do. Fullscreen is borderless (:desktop), unless +exclusive+,
    # as DOT_POPPER_FULLSCREEN=exclusive asks, to compare how each works
    # with a system overlay and a TV's game mode.
    class DesktopWindow < Data.define(:exclusive)
      def offered? = true

      def fullscreen?
        on, = ::Lota::Window.fullscreen
        on
      end

      def toggle_fullscreen = ::Lota::Window.set_fullscreen(!fullscreen?, exclusive ? :exclusive : :desktop)
      def quit = ::Lota::Event.quit
    end
  end
end
