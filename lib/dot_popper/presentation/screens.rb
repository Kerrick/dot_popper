# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every screen of the game, each an object that answers for itself
    # (doc/design/screens.md, ADR-0018). The Show makes one of each as it is
    # made, and Show#screen is the one place that says which is on top;
    # every press, button, key and scroll asks that screen.
    module Screens
      # One of each screen for +show+, by name: a screen over Home by the
      # name Show#page gives it, the rest by their own.
      def self.made_for(show)
        { home: Home, new_theme: NewTheme, tutorial: Tutorial, game: Game, game_over: GameOver, share_preview: SharePreview,
          offer: Offer, stats: Stats, achievements: Achievements, achievement_dialog: AchievementDialog, themes: Themes,
          settings: Settings, credits: Credits, privacy: Privacy, server: ChangeServer, friend_groups: FriendGroups }
          .transform_values { it.new(show) }.freeze
      end

      # What every screen answers, and what a screen answers where it has
      # nothing of its own. +show+ is the Show the screen belongs to, whose
      # state it reads and changes.
      class Screen
        attr_reader :show

        def initialize(show) = @show = show

        # The buttons this screen offers (Control), each where it is drawn
        # and where a press reaches it. Show#controls keeps their reaches
        # apart.
        def controls = []

        # Presses this screen's main button, as Enter, Space, a gamepad's
        # Start, or its A aimed at no button do.
        def primary = nil

        # Escape, Android's Back, or a gamepad's B: Back, Close or Home
        # where the screen has one. Says whether it had, so that elsewhere
        # the key can do its usual job.
        def back = false

        # A gamepad's X, Y, LB, RB, LT or View/Select (+button, as
        # GamepadButtons names it) on this screen, as the screen labels it.
        def pad(button) = nil

        # A gamepad's Start: the main button, unless the screen holds it.
        def start = primary

        # A key typed on a keyboard (+key+, as Shell::LotaInput names it)
        # that this screen takes as its own. Says whether it took it.
        def type(key) = false

        # The system's paste shortcut (Ctrl+V, or Cmd+V on a Mac), where the
        # screen takes a paste. Says whether it took it.
        def paste = false

        # Ctrl+B or Cmd+B: Buy, where the screen has it. Says whether it
        # took it.
        def buy = false

        # Whether this screen's list scrolls, by the wheel, the keys, a
        # drag and the right stick.
        def scrolls? = false

        # Whether the left stick and d-pad scroll it too, instead of moving
        # the gamepad's cursor.
        def stick_scrolls? = false

        private

        def layout = show.layout

        # A button drawn at +frame+, which a press reaches within a dot's
        # width, short of the safe area's bottom.
        def button(name, frame) = Control.new(name:, frame:, reach: within_safe(frame.reach(2 * show.radius)))

        # A screen's main button, which a press reaches more generously.
        def primary_button(name, frame) = Control.new(name:, frame:, reach: layout.primary_reach(frame, show.cabinet.field.radius))

        def back_button = button(:back, layout.back_button)

        def within_safe(reach) = reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)
      end

      # A screen over Home, which Show#page names, with Back in its corner:
      # Back, and its main button, close it.
      class Page < Screen
        def primary = show.close_page

        def back
          show.close_page
          true
        end
      end
    end
  end
end
