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
      end
    end
  end
end
