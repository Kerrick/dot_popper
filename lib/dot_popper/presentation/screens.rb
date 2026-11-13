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
    end
  end
end
