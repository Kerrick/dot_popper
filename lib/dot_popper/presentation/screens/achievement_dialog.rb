# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # An achievement's dialog, over Achievements (the layout is
      # Presentation::AchievementDialog): Close, Get Pro for a Free
      # player, and with a controller the previous and next achievement.
      class AchievementDialog < Screen
        def controls = show.dialog_plan.buttons.map { |name, rect| button(name, rect) }

        def primary = show.close_dialog

        def back
          show.close_dialog
          true
        end

        # LB and RB: the previous and next achievement.
        def pad(button)
          case button
          in :lb then show.step_achievement(-1)
          in :rb then show.step_achievement(1)
          else nil
          end
        end

        # The grid under it still scrolls, by the wheel, the keys and the
        # right stick.
        def scrolls? = true
      end
    end
  end
end
