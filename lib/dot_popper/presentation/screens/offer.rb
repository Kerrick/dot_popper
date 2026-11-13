# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The offer of Pro, over the screen it was opened from (OfferScreen):
      # Buy, Restore Purchases or Paste license key, and Back. It sells
      # through +buy_pro+ (UseCases::BuyPro), shows what +storefront+ says
      # of the store, and thanks the player once +entitlement+ has Pro.
      class Offer < Screen
        def initialize(show, buy_pro:, storefront:, entitlement:)
          super(show)
          @buy_pro = buy_pro
          @storefront = storefront
          @entitlement = entitlement
          @focus = nil
          @for_play = false
          @key_hint = nil
        end

        # What it leads with (:themes, :achievements, :groups, :games), or
        # nil when it was not opened by a tap on something Pro has; the
        # achievement a Free player tapped; and whether it was opened by
        # Play with no game left, which it says.
        attr_reader :focus, :achievement, :for_play

        # A Free player tapped something that comes with Pro (+feature+ is
        # :achievements, :themes or :groups): it opens over the screen they
        # are on, leading with it, and Back closes it to that same screen,
        # open as it was, so no one loses their place.
        def open_led_by(feature)
          return if @entitlement.pro? || opened?

          show.open_layer(self)
          @focus = feature
          @buy_pro.open
          sounds.play(:tick)
        end

        # The achievement a Free player's Get Pro came from, which it leads
        # with.
        def led_by_achievement(id) = @achievement = id

        # Opens over the screen in view, and asks the store for the price,
        # or asks again if an earlier request was never answered.
        def open_plainly
          return unless @buy_pro.offered?

          show.open_layer(self)
          @focus = nil
          @buy_pro.open
          sounds.play(:tick)
        end

        # Opened by Play or Play again with no game left: it leads with
        # games, and says why.
        def open_for_play
          @for_play = true
          open_plainly
          @focus = :games
        end

        # Back to the screen it was opened over, with a tick unless +quiet+.
        def close(quiet: false)
          @for_play = false
          show.close_layer(self)
          @focus = nil
          sounds.play(:tick, pitch: 0.8) unless quiet
        end

        # As Home shows: nothing of it is open.
        def closed_at_home = @for_play = false

        # The words and parts to lay out (OfferScreen), and where they go.
        def layout_screen
          OfferScreen.new(layout:, type: style::TYPE, words:, measure:, offering: !@entitlement.pro?,
                          note: (words.offer[:no_games] if for_play), focus:, art:,
                          sold: @storefront.sold?, second: keys? ? :paste : :restore)
        end

        def plan = layout_screen.plan

        # How tall its picture of what was tapped is: the themes' cards,
        # the achievement's card, or a feature's sign.
        def art
          case focus
          when :themes then layout.short? ? 64.0 : 100.0
          when :achievements then layout.short? ? 84.0 : 110.0
          else layout.short? ? 40.0 : 56.0
          end
        end

        # Whether the store takes a license key (WebsiteStore), rather than
        # restoring its purchases.
        def keys? = @storefront.keys?

        # The price the store gave, or nil before it has.
        def price = @storefront.price

        # What it says of how the store is getting on: thanks once the
        # player owns Pro, and otherwise a word only when there is something
        # to say.
        def status
          return words.offer[:thanks] if @entitlement.pro?
          return "#{words.offer[:typing]} #{typed_tail}" if @storefront.respond_to?(:typed) && !@storefront.typed.empty? && @storefront.status == :ready

          words.offer.fetch(@storefront.status, "")
        end

        # Buy's words, with the controller's button that presses it (Y) while
        # a controller is in use, or until a pointer or a controller is
        # used, the keyboard's (#key_hint). Buy's other ways are its own
        # button and Ctrl+B or Cmd+B; none is a press that means continue or
        # back elsewhere.
        def buy_label
          label = price ? format(words.offer[:buy], price) : words.offer[:retry]
          return "#{label} (Y)" if show.input == InputKind::GAMEPAD

          @key_hint ? "#{label} (#{@key_hint})" : label
        end

        # Buy's key on a computer's keyboard ("Ctrl+B", or "⌘B" on a Mac),
        # since a key was pressed, or nil since a pointer or a controller was.
        attr_writer :key_hint

        # Buy where the store gave a price, and otherwise the same button's
        # "Try again" (UseCases::BuyPro). Says whether it took the press.
        def buy = @buy_pro.buy

        def restore = @buy_pro.restore

        # Paste license key: what is on the clipboard, entered as a key, on a
        # copy that takes one (WebsiteStore). A key that is good is Pro at
        # once, which Entitlement announces as Pro arriving.
        def paste_key
          return unless opened? && keys?

          @buy_pro.paste
          sounds.play(:tick)
        end

        # A key typed into a copy that takes a license key, on a computer:
        # Paste license key's other way in (WebsiteStore#type).
        def type_license_key(key) = @buy_pro.type(key)

        def controls
          plan = self.plan
          [(button(:buy, plan[:buy]) if plan.key?(:buy)),
           (button(:restore, plan[:restore]) if plan.key?(:restore)),
           (button(:paste, plan[:paste]) if plan.key?(:paste)),
           back_button].compact
        end

        # Back: Buy has only its own controls, so no one buys by reflex.
        def primary = close

        def back
          close
          true
        end

        # X Paste license key on a copy that takes one, or else Restore
        # Purchases; Y Buy.
        def pad(button)
          case button
          in :x then keys? ? paste_key : restore
          in :y then buy
          else nil
          end
        end

        # A license key typed, on a copy that takes one.
        def type(key) = keys? && type_license_key(key)

        # Paste license key, on a copy that takes one.
        def paste
          return false unless keys?

          paste_key
          true
        end

        def pressed(name, by)
          case name
          in :buy then buy
          in :restore then restore
          in :paste then paste_key
          in :back then close
          else nil
          end
        end

        def covers? = true

        private

        # The last of the key being typed, for the line to show.
        def typed_tail
          typed = @storefront.typed
          typed.length > 24 ? "…#{typed[-24..]}" : typed
        end
      end
    end
  end
end
