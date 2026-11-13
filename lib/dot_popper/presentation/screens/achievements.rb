# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Achievements, over Home (AchievementsScreen): a grid of cells that
      # scrolls, each opening its achievement's dialog, and Back.
      class Achievements < Page
        # Where the grid goes (AchievementsScreen).
        def grid = AchievementsScreen.new(layout:, ids: DotPopper::Achievement::IDS)

        # Each cell where it is on screen, with the list scrolled to fit its
        # window.
        def cells
          grid = self.grid
          show.list_fit(grid.height, grid.window.height)
          grid.cells(show.scroll.offset)
        end

        def controls
          window = grid.window
          cells = self.cells.select { it.rect.y < window.bottom && it.rect.bottom > window.y }.map do
            control = button([:achievement, it.id], it.rect.cut(top: window.y, bottom: window.bottom))
            control.with(reach: control.reach.cut(top: window.y, bottom: window.bottom))
          end
          cells << back_button
        end

        # X: the first achievement's dialog.
        def pad(button) = (show.screens.fetch(:achievement_dialog).open_at(DotPopper::Achievement::IDS.first) if button == :x)

        def scrolls? = true

        def answers = [*super, :achievement]

        def pressed(name, by)
          case name
          in [:achievement, id] then show.screens.fetch(:achievement_dialog).open_at(id)
          else super
          end
        end

        def list_row?(name) = name in [:achievement, _]

        def empty(_x, y, by) = show.start_scroll(by, y)
      end
    end
  end
end
