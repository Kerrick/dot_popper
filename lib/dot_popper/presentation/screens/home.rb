# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Home: the game's name, Play, today's goal, the large buttons and
      # the bottom row (HomeScreen lays them out).
      class Home < Screen
        def controls
          plan = show.home_plan
          buttons = plan.tiles.map { |name, rect| button(name, rect) }
          plan.pills.each { |name, rect| buttons << button(name, rect) }
          buttons << primary_button(:play, plan.play_button)
        end

        def primary = show.play

        # X Stats, Y How to play, LB Achievements, RB Themes, LT Friend
        # groups, and View/Select Settings.
        def pad(button)
          case button
          in :x then show.open_stats
          in :y then show.how_to_play
          in :lb then show.open_achievements
          in :rb then show.open_themes
          in :lt then show.open_groups
          in :select then show.open_settings
          else nil
          end
        end
      end
    end
  end
end
