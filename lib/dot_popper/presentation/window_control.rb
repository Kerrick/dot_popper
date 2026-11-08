# frozen_string_literal: true

module DotPopper
  module Presentation
    # The window, for a system whose game the player cannot switch to
    # fullscreen or quit from inside it, and for the tests: a phone or
    # tablet, where the game fills the screen, iOS leaves quitting to the
    # system, and Android's Back leaves the app. The title offers no
    # window buttons for it. Anything that answers +offered?+,
    # +fullscreen?+, +toggle_fullscreen+ and +quit+ can stand in for it, as
    # Shell::DesktopWindow does on a desktop.
    class NoWindowControl < Data.define
      def offered? = false
      def fullscreen? = false
      def toggle_fullscreen = nil
      def quit = nil
    end
  end
end
