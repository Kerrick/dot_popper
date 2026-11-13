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

        # Back: Buy has only its own controls, so no one buys by reflex.
        def primary = show.close_offer

        def back
          show.close_offer
          true
        end

        # X Paste license key on a copy that takes one, or else Restore
        # Purchases; Y Buy.
        def pad(button)
          case button
          in :x then show.keys? ? show.paste_key : show.restore
          in :y then buy
          else nil
          end
        end

        # Buy where Pro is sold and not yet bought (UseCases::BuyPro).
        def buy = show.buy

        # A license key typed, on a copy that takes one (WebsiteStore#type).
        def type(key) = show.keys? && show.typed_license_key(key)

        # Paste license key, on a copy that takes one.
        def paste
          return false unless show.keys?

          show.paste_key
          true
        end

        def pressed(name, by)
          case name
          in :buy then show.buy
          in :restore then show.restore
          in :paste then show.paste_key
          in :back then show.close_offer
          else nil
          end
        end

        def covers? = true
      end
    end
  end
end
