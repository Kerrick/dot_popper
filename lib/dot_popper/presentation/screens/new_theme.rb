# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The card that tells of a new theme, once, over Home (ArrivalPlan):
      # its switch, and Not now.
      class NewTheme < Screen
        # No button for its first moments (Style::ARRIVAL_GRACE), so a press
        # meant for Home as it came answers nothing.
        def controls
          return [] unless show.arrival_settled?

          plan = show.arrival_plan
          [button(:arrival_later, plan.later_button), button(:arrival_use, plan.use_button)]
        end
      end
    end
  end
end
