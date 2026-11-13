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

        # Y Share my score; LB opens the new achievement, and RB the friend
        # group, as their lines say.
        def pad(button)
          return show.share if button == :y

          chip = { lb: :over_achievement, rb: :over_group }[button] or return
          show.open_from_game_over(chip == :over_achievement ? :achievement : :group) if show.game_over_chips.any? { it.name == chip && it.opens }
        end

        # Escape or B goes Home, as Home does.
        def back
          show.continue_on
          true
        end

        def pressed(name, by)
          case name
          in :play_again then show.play_again
          in :home then show.continue_on
          in :share then show.share
          in :over_achievement then show.open_from_game_over(:achievement)
          in :over_group then show.open_from_game_over(:group)
          else nil
          end
        end

        # A press away from its buttons waits, as it may drag the pile.
        def waits_for_release?(x, y) = show.control_at(x, y).nil?

        def announces? = true
      end
    end
  end
end
