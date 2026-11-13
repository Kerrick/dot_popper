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

        # H opens How to play.
        def type(key)
          return false unless key == :h

          show.how_to_play
          true
        end

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

        # A tap on one of Home's bright dots pops it, for fun.
        def empty(x, y, _by) = show.toy_tap(x, y)

        def pressed(name, by)
          case name
          in :play then show.play
          in :stats then show.open_stats
          in :achievements then show.open_achievements
          in :themes then show.open_themes
          in :groups then show.group_panel.open
          in :how_to_play then show.how_to_play
          in :settings then show.open_settings
          in :quit then show.window.quit
          else nil
          end
        end

        def announces? = true
      end
    end
  end
end
