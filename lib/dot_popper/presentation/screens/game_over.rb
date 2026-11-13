# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Game Over, over the finished game's pile (GameOverScreen): Play
      # again, Home, Share my score, and the lines that open something.
      class GameOver < Screen
        def controls
          plan = show.game_over_plan or return []
          chips = show.game_over_chips.each_with_index.filter_map { |chip, i| button(chip.name, plan[[:chip, i]]) if chip.opens && plan[[:chip, i]] }
          [*chips, (button(:home, plan.home_button) if plan.home_button), (button(:share, plan.share_button) if plan.share_button),
           (primary_button(:play_again, plan.play_button) if plan.play_button)].compact
        end

        def primary = show.play_again

        # Escape or B goes Home, as Home does.
        def back
          show.continue_on
          true
        end
      end
    end
  end
end
