# frozen_string_literal: true

module DotPopper
  module Presentation
    # A key pressed on a keyboard: +key+, as the game names it
    # (Shell::LotaInput#key), or nil for a key the game doesn't name; and
    # +held+, the modifier keys held with it: +:ctrl+, +:alt+, and
    # +:command+ (Cmd on a Mac, the Windows or Super key elsewhere).
    class KeyPress < Data.define(:key, :held)
      def initialize(key:, held: []) = super(key:, held: held.freeze)

      # Whether any of +modifiers+ is held.
      def held?(*modifiers) = modifiers.any? { held.include?(it) }
    end

    # Where the shell hands each of the player's inputs, as the game's
    # own events, and what each does on the screen on top. What only the
    # engine can do it asks of +shell+:
    #
    # [splash?], [skip_splash] whether setdef's splash shows, and ending it
    # [quit] closing the game
    # [toggle_fullscreen] a computer's window in or out of fullscreen
    #
    # +platform+ (Platform) says what the system allows: a phone's or
    # tablet's keyboard neither quits nor leaves fullscreen, and an iOS
    # app never quits itself.
    class InputHandler
      def initialize(show:, platform:, shell:)
        @show = show
        @platform = platform
        @shell = shell
      end

      def call(event)
        case event
        in KeyPress then key(event)
        end
      end

      PRIMARY_KEYS = %i[enter space].freeze

      private

      # A key, in order; the first that applies wins.
      def key(press)
        return @shell.skip_splash if @shell.splash?

        @show.keyboard_used(@platform.command_key? ? "⌘B" : "Ctrl+B") unless @platform.touch?
        key = press.key or return
        return if key == :v && press.held?(:ctrl, :command) && @show.paste_shortcut
        # Ctrl+B or Cmd+B buys on the offer: a chord, so no press that means
        # continue or back, and no letter of a typed license key, buys.
        return if key == :b && press.held?(:ctrl, :command) && @show.buy_shortcut
        return if @show.type_key(key)
        return @show.sounds.toggle_mute if key == :m
        return if @show.scroll_key(key)
        # Enter or Space presses the screen's main button, on any device;
        # Alt+Enter (Cmd+Enter on a Mac) is fullscreen's instead.
        return @show.primary if PRIMARY_KEYS.include?(key) && !(key != :space && press.held?(:alt, :command))
        # Escape, which Android's Back arrives as, goes back from the
        # Stats screen or Game Over first, on any device.
        return if key == :escape && @show.back
        # On Home Android's Back leaves the app, as Back on an app's
        # first screen does; in a game it does nothing, so a stray edge
        # swipe never throws a game away. iOS apps never quit themselves.
        return @shell.quit if key == :escape && @platform.quits_itself? && @show.home?
        # A tablet's keyboard neither quits the app nor takes it out of
        # fullscreen: iOS apps are left by the system, never by the app.
        return if @platform.touch?

        case key
        when :escape then @shell.quit
        when :f11 then @shell.toggle_fullscreen
        when :enter then @shell.toggle_fullscreen if press.held?(:alt, :command)
        end
      end
    end
  end
end
