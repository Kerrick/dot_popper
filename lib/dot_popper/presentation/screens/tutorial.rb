# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The Tutorial over the first game, paused (ADR-0016): its only
      # button is Skip.
      class Tutorial < Screen
        def controls = [button(:skip, layout.skip_button)]
      end
    end
  end
end
