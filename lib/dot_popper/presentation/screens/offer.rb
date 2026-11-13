# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The offer of Pro, over the screen it was opened from (OfferScreen):
      # Buy, Restore Purchases or Paste license key, and Back.
      class Offer < Screen
        def controls
          plan = show.offer_plan
          [(button(:buy, plan[:buy]) if plan.key?(:buy)),
           (button(:restore, plan[:restore]) if plan.key?(:restore)),
           (button(:paste, plan[:paste]) if plan.key?(:paste)),
           back_button].compact
        end
      end
    end
  end
end
