# frozen_string_literal: true

module DotPopper
  module UseCases
    # Buying Pro, from the offer: asking the store (+store+, the
    # Storefront port) for the price as the offer opens, Buy, Restore
    # Purchases, and a license key pasted or typed on a copy that takes
    # one; once the player has Pro (+entitlement+, Entitlement), Buy and a
    # typed key do nothing. The store is heard only while no game
    # is in play (+cabinet+, Cabinet), so a purchase never lands mid-game.
    # When Pro arrives (Entitlement::ProGranted), the player's friend
    # groups (+friend_groups+) hear of every achievement already earned
    # (+achievements+, Achievements), which a Free player's games kept but
    # never reported.
    class BuyPro
      def initialize(store:, entitlement:, cabinet:, achievements:, friend_groups:)
        @store = store
        @entitlement = entitlement
        @cabinet = cabinet
        @achievements = achievements
        @friend_groups = friend_groups
        entitlement.subscribe(self)
      end

      # Whether Pro can be offered: where there is a store, to a player
      # who has not bought it.
      def offered? = @store.offered? && !@entitlement.pro?

      # The offer opened: asks the store for the price and what this
      # player owns, or asks again if an earlier request went unanswered.
      def open = @store.connect

      # Buy, where Pro is sold and not yet bought: with the store's price,
      # a purchase, and before one has come, Buy's "Try again", which asks
      # again. Says whether it was taken.
      def buy
        return false if @entitlement.pro? || !@store.sold?

        @store.price ? @store.buy : @store.connect
        true
      end

      def restore = @store.restore

      # Paste license key, on a copy that takes one.
      def paste = @store.paste

      # A key typed as a license key, on a copy that takes one; says
      # whether it was taken.
      def type(key) = !@entitlement.pro? && @store.type(key)

      # Hears the store, +seconds+ on, unless a game is in play.
      def update(seconds)
        @store.update(seconds) unless @cabinet.playing?
      end

      # Pro arrived: what was earned while Free counts now.
      def call(_granted)
        @friend_groups.report_achievements(@achievements.earned)
      end
    end
  end
end
