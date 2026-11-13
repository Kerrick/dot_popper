# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Themes, over Home (ThemesLayout): a card for each theme, with a
      # controller the previous and next, and Back.
      class Themes < Screen
        def controls
          plan = show.themes_layout
          steps = show.input == InputKind::GAMEPAD ? plan.steps.map { |name, rect| button(name, rect) } : []
          plan.cards.map { button(it.theme, it.rect) } + steps << back_button
        end
      end
    end
  end
end
