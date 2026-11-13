# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The share preview over Game Over, on a computer (ShareScreen):
      # Close and Copy.
      class SharePreview < Screen
        def controls
          plan = show.share_plan
          [button(:close, plan.close), button(:copy, plan.copy)]
        end
      end
    end
  end
end
