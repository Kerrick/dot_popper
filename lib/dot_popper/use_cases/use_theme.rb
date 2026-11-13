# frozen_string_literal: true

module DotPopper
  module UseCases
    # Using a theme: a theme is Metagame's (+themes+, the
    # Presentation::ThemeKeeper that keeps which are unlocked and which
    # the player chose), and using one other than the ordinary is Pro's
    # (+entitlement+, Entitlement). A Free player sees every theme, and is
    # told of a new one, but uses the ordinary theme, and choosing another
    # leads to the offer of Pro instead.
    class UseTheme
      def initialize(themes:, entitlement:)
        @themes = themes
        @entitlement = entitlement
        refresh
      end

      # The current theme (as Theme), which changes only when the player
      # uses one or #refresh takes it up, between games.
      attr_reader :current

      # Whether choosing a theme leads to Pro, as for a Free player.
      def locked? = !@entitlement.pro?

      # The player chose +theme+: :offer for a Free player, who is offered
      # Pro instead; :same when it is already current or not open to use;
      # or :used, and it is current from now on.
      def call(theme)
        return :offer if locked?
        return :same if theme == current || !@themes.open?(theme)

        @themes.use(theme)
        refresh
        :used
      end

      # Takes up which theme is current: the one a Pro player chose, and
      # for a Free player the ordinary one.
      def refresh
        @current = locked? ? @themes.ordinary : @themes.chosen
      end
    end
  end
end
