# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The Tutorial over the first game, paused (ADR-0016): its only
      # button is Skip.
      class Tutorial < Screen
        def controls = [button(:skip, layout.skip_button)]

        # Escape or B skips it.
        def back
          show.skip_tutorial
          true
        end

        def answers = [:skip]

        def pressed(name, _by) = (show.skip_tutorial if name == :skip)

        # A tap on Skip presses it; any other is the Tutorial's own, which
        # it passes on to its scene (Presentation::Tutorial#tap).
        def tap(x, y, by)
          return super if show.control_at(x, y)

          show.tutorial.tap(x, y)
        end
      end
    end
  end
end
