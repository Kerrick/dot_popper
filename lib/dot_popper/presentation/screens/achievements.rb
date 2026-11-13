# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Achievements, over Home (AchievementsScreen): a grid of cells that
      # scrolls, each opening its achievement's dialog, and Back.
      class Achievements < Page
        def controls
          window = show.achievements_layout.window
          cells = show.achievement_cells.select { it.rect.y < window.bottom && it.rect.bottom > window.y }.map do
            control = button([:achievement, it.id], it.rect.cut(top: window.y, bottom: window.bottom))
            control.with(reach: control.reach.cut(top: window.y, bottom: window.bottom))
          end
          cells << back_button
        end
      end
    end
  end
end
