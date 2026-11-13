# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Change Server, over Settings, only while setdef is gone
      # (ServerScreen; ADR-0011): Paste server address, the reset, and Back.
      class ChangeServer < Page
        def controls
          plan = show.server_plan
          [button(:server_paste, plan.paste), (button(:server_reset, plan.reset) if plan.reset), back_button].compact
        end
      end
    end
  end
end
