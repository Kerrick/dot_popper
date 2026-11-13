# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Themes, over Home (ThemesLayout): a card for each theme, with a
      # controller the previous and next, and Back.
      class Themes < Page
        def controls
          plan = show.themes_layout
          steps = show.input == InputKind::GAMEPAD ? plan.steps.map { |name, rect| button(name, rect) } : []
          plan.cards.map { button(it.theme, it.rect) } + steps << back_button
        end

        # LB and RB: use the previous or next theme.
        def pad(button)
          case button
          in :lb then show.step_theme(-1)
          in :rb then show.step_theme(1)
          else nil
          end
        end

        def pressed(name, by)
          case name
          in Theme => theme then show.use(theme)
          in :theme_prev then show.step_theme(-1)
          in :theme_next then show.step_theme(1)
          else super
          end
        end
      end
    end
  end
end
