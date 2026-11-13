# frozen_string_literal: true

module DotPopper
  # A test build's own answers where a developer setting may change what a
  # player has: Pro without a purchase, and the free-game limit. A build
  # for sale has none of this, and Build.settings drops these settings
  # from its environment as well.
  class Entitlement
    FORCED_BY = "DOT_POPPER_PRO"

    # A test build's, which takes the fake store's receipts (Receipt::TEST).
    def self.test = new(trust: Receipt::TEST)

    # DOT_POPPER_PRO=1 stands in for a purchase, to try Pro out, and
    # DOT_POPPER_PRO=0 is a free player; unset, as a build for sale.
    module ForcedByTestBuild
      def forced?(env, platform: nil)
        value = env.fetch(FORCED_BY, "")
        value.empty? ? super : value == "1"
      end
    end
    singleton_class.prepend(ForcedByTestBuild)
  end

  class FreeGames
    # The developer setting that starts a new save with that many first
    # games and that many a day, to try the limit.
    STARTING = "DOT_POPPER_FREE_GAMES"

    # In a test build, not the autoplay bot, and not a GUI scenario unless
    # it sets STARTING to try the limit; in a build for sale, everyone.
    module PlayersOfTestBuild
      def player?(env, channel:)
        return super if Build.store?(channel)
        return false if env["DOT_POPPER_AUTOPLAY"] == "1"

        env.fetch("DOT_POPPER_SCENARIO", "").empty? || env.key?(STARTING)
      end

      def starting(env) = Integer(env.fetch(STARTING, ""), exception: false)
    end
    singleton_class.prepend(PlayersOfTestBuild)
  end
end
