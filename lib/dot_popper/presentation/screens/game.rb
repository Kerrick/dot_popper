# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # A game in play. It offers no button: only a press at a place
      # reaches the game, so nothing scores without aiming.
      class Game < Screen
        # Every tap goes to the game at once.
        def tap(x, y, _by) = show.cabinet.press(x, y)
      end
    end
  end
end
