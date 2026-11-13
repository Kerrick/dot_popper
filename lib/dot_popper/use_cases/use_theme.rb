# frozen_string_literal: true

module DotPopper
  module UseCases
    # Using a theme: which themes a player has is Gameplay and Metagame's
    # (+themes+, Themes, which keeps which are released and which the
    # player chose), and using one other than the ordinary is Pro's
    # (+entitlement+, Entitlement). A Free player sees every theme, and is
    # told of a new one, but uses the ordinary theme, and choosing another
    # leads to the offer of Pro instead. Themes are named by their keys
    # (Theme#key); what each draws is the presentation's.
    class UseTheme
      def initialize(themes:, entitlement:)
        @themes = themes
        @entitlement = entitlement
        refresh
      end

      # The current theme's key, which changes only when the player uses
      # one or #refresh takes it up, between games.
      attr_reader :current

      # Whether choosing a theme leads to Pro, as for a Free player.
      def locked? = !@entitlement.pro?

      # The player chose the theme +key+: :offer for a Free player, who is
      # offered Pro instead; :same when it is already current or not open
      # to use; or :used, and it is current from now on.
      def call(key)
        return :offer if locked?
        return :same if key == current || !@themes.open?(key)

        @themes.use(key)
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
