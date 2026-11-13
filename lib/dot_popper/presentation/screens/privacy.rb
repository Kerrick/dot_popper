# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Privacy, over Settings (PrivacyScreen): Read the privacy policy,
      # Delete my friend group data for a player the group server knows,
      # and Back.
      class Privacy < Page
        def controls
          plan = show.privacy_plan
          [button(:policy, plan.policy), (button(:privacy_delete, plan.delete) if plan.delete), back_button].compact
        end

        # X Read the privacy policy; Y hold to delete my friend group data.
        def pad(button)
          case button
          in :x then show.open_policy
          in :y then show.group_panel.hold_delete(:y, show.now)
          else nil
          end
        end
      end
    end
  end
end
