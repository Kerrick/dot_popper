# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The offer of Pro, over the screen it was opened from (OfferScreen):
      # Buy, Restore Purchases or Paste license key, and Back. It asks
      # everything of +buy_pro+ (UseCases::BuyPro): it sells through it,
      # shows what it says of the store, and thanks the player once it says
      # they have Pro.
      class Offer < Screen
        def initialize(show, buy_pro:)
          super(show)
          @buy_pro = buy_pro
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
          return if thanking? || opened?

          show.open_layer(self)
          @focus = feature
          @buy_pro.open
          sounds.play(:tick)
        end

        # The achievement a Free player's Get Pro came from, which it leads
        # with.
        def led_by_achievement(id) = @achievement = id

        # Whether Pro can be offered at all: where there is a store, to a
        # player who has not bought it.
        def offered? = @buy_pro.offered?

        # Hears the store, +seconds+ on, while no game is in play
        # (UseCases::BuyPro#update).
        def update(seconds) = @buy_pro.update(seconds)

        # Pro arrived (a ProGranted, which the composition root subscribes
        # it to hear): a tick marks a store's purchase landing while
        # it is open. A license key entered has had its own tick as it was
        # pressed.
        def call(granted)
          sounds.play(:tick, pitch: 1.3) if opened? && granted.by == :receipt
        end

        # Opens over the screen in view, and asks the store for the price,
        # or asks again if an earlier request was never answered.
        def open_plainly
          return unless offered?

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
          OfferScreen.new(layout:, type: style::TYPE, words:, measure:, offering: !thanking?,
                          note: (words.offer[:no_games] if for_play), focus:, art:,
                          sold: @buy_pro.sold?, second: keys? ? :paste : :restore)
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
        def keys? = @buy_pro.keys?

        # The price the store gave, or nil before it has.
        def price = @buy_pro.price

        # What it says of buying, as BuyPro#status answers: thanks once the
        # player has Pro, and otherwise a word only when there is something
        # to say of the store.
        def status
          return "#{words.offer[:typing]} #{typed_tail}" if @buy_pro.status == :ready && !@buy_pro.typed.empty?

          words.offer.fetch(@buy_pro.status, "")
        end

        # Buy's words, with the controller's button that presses it (Y) while
        # a controller is in use, or until a pointer or a controller is
        # used, the keyboard's (#key_hint). Buy's other ways are its own
        # button and Ctrl+B or Cmd+B; none is a press that means continue or
        # back elsewhere.
        def buy_label
          label = price ? format(words.offer[:buy], price) : words.offer[:retry]
          return "#{label} (#{GamepadButtons::LABELS.fetch(BUTTONS.key(:buy))})" if show.input == InputKind::GAMEPAD

          @key_hint ? "#{label} (#{@key_hint})" : label
        end

        # The key that buys, from the offer's own keys (KEY_BINDINGS):
        # "Ctrl+B", or "⌘B" where the system's command key is Cmd
        # (+command_key+).
        def buy_key(command_key:) = KEY_BINDINGS.find { it.does == :buy }.hint(command_key:)

        # Buy's key on a computer's keyboard ("Ctrl+B", or "⌘B" on a Mac),
        # since a key was pressed, or nil since a pointer or a controller was.
        attr_writer :key_hint

        # Buy where the store gave a price, and otherwise the same button's
        # "Try again" (UseCases::BuyPro). Says whether it took the press.
        def buy = @buy_pro.buy

        def restore = @buy_pro.restore

        # Paste license key: what is on the clipboard, entered as a key, on a
        # copy that takes one (WebsiteStore). A key that is good is Pro at
        # once, which is announced as Pro arriving (#call).
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

        # A controller's buttons here, by what each presses: Y Buy, and X
        # Paste license key on a copy that takes one, or else Restore
        # Purchases.
        BUTTONS = { y: :buy, x: :paste_or_restore }.freeze

        def pad(button)
          case BUTTONS[button]
          in :paste_or_restore then keys? ? paste_key : restore
          in :buy then buy
          else nil
          end
        end

        # Ctrl+V or Cmd+V pastes a license key, and Ctrl+B or Cmd+B buys:
        # chords, so no press that means continue or back, and no letter
        # of a typed license key, buys. Then, on a copy that takes license
        # keys, a letter, digit or hyphen is typed into one, and Backspace,
        # Delete or Enter edits or enters it, with Ctrl or Cmd held or not,
        # so a key's letters are never shortcuts. While a key is being
        # typed, Space does nothing: a key's text ignores spaces, so one
        # typed as it is printed, in groups, never closes the offer.
        def key_bindings = KEY_BINDINGS
        KEY_BINDINGS = [
          KeyBinding.new(keys: :v, with: KeyBinding::COMMAND, does: :paste),
          KeyBinding.new(keys: :b, with: KeyBinding::COMMAND, does: :buy),
          KeyBinding.new(keys: [*("a".."z"), *("0".."9"), :minus, :backspace, :delete, :enter].map(&:to_sym),
                         held_or_not: true, does: :type),
          KeyBinding.new(keys: :space, does: :typing?)
        ].freeze

        # A license key typed, on a copy that takes one.
        def type(key) = keys? && type_license_key(key)

        # Whether a license key is being typed, on a copy that takes one.
        def typing? = keys? && !@buy_pro.typed.empty?

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

        # Whether it thanks the player (BuyPro#status), in place of selling:
        # no buttons but Back, and not opened over what was tapped.
        def thanking? = @buy_pro.status == :thanks

        # The last of the key being typed, for the line to show.
        def typed_tail
          typed = @buy_pro.typed
          typed.length > 24 ? "…#{typed[-24..]}" : typed
        end
      end
    end
  end
end
