# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The share preview over Game Over, on a computer (ShareScreen):
      # Close and Copy.
      class SharePreview < Screen
        # What it shows (Presentation::SharePreview): the text, and when it
        # was copied.
        attr_accessor :preview

        def controls
          plan = show.share_plan
          [button(:close, plan.close), button(:copy, plan.copy)]
        end

        def primary = show.copy_result

        def back
          show.close_share
          true
        end

        # Y again copies, as Copy does.
        def pad(button) = (show.copy_result if button == :y)

        def pressed(name, by)
          case name
          in :copy then show.copy_result
          in :close then show.close_share
          else nil
          end
        end

        # A tap beside the card closes it; on the card it does nothing.
        def empty(x, y, _by) = (show.close_share unless show.share_plan.card.contains?(x, y))
      end
    end
  end
end
