# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The card that tells of a new theme, once, over Home (ArrivalPlan):
      # its switch, and Not now. It waits for its answer, so nothing of
      # Home's under it takes a press.
      class NewTheme < Screen
        # +themes+ (DotPopper::Themes) remembers it was told; +use_theme+
        # (UseCases::UseTheme) uses it, or for a Free player leads to Pro.
        def initialize(show, themes:, use_theme:)
          super(show)
          @themes = themes
          @use_theme = use_theme
        end

        # The switch's word: "Use Ghost", or a Free player's "Get Pro",
        # since it opens the offer.
        def use_word = @use_theme.locked? ? words.offer.fetch(:entry) : format(words.themes.fetch(:use), words.themes.fetch(show.arrival.key))

        # Where its parts go (ArrivalPlan).
        def plan = ArrivalPlan.new(layout:, word: (use_word if show.arrival?), measure:)

        # The player answered: it is told once. A Pro player's switch uses
        # the theme at once; a Free player's opens the offer, the same as
        # tapping Themes. For its first moments (Style::ARRIVAL_GRACE) it
        # answers nothing, so a press meant for Home as it came does not.
        def answer(use:)
          return :waiting unless show.arrival_settled?

          theme = show.arrival or return

          @themes.told(theme.key)
          return sounds.play(:tick, pitch: 0.8) unless use
          return show.offer.open_led_by(:themes) if @use_theme.call(theme.key) == :offer

          sounds.play(:tick, pitch: 1.2)
        end

        # No button for its first moments, as it answers nothing.
        def controls
          return [] unless show.arrival_settled?

          plan = self.plan
          [button(:arrival_later, plan.later_button), button(:arrival_use, plan.use_button)]
        end

        def primary = answer(use: true)

        def back
          answer(use: false)
          true
        end

        def pressed(name, by)
          case name
          in :arrival_use then answer(use: true)
          in :arrival_later then answer(use: false)
          else nil
          end
        end

        def announces? = true
      end
    end
  end
end
