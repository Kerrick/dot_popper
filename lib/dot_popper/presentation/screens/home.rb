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
      end
    end
  end
end
